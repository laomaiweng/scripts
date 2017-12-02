#!/usr/bin/python3

import argparse
import os
import pathlib
import re
import sys
import urllib

import bs4
import requests
import tqdm


TOR = {'http': 'socks5://localhost:9050',
       'https': 'socks5://localhost:9050'}

PROXIES = None


def green(s):
    return '\033[1;32m' + s + '\033[0m'


def red(s):
    return '\033[1;31m' + s + '\033[0m'


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('-a', '--all', action='store_true', help='grab all documents without asking')
    parser.add_argument('-e', '--extension', metavar='.EXT', action='append', default=[], help='extension of files to grab (can be specified multiple times, default: .pdf)')
    parser.add_argument('-n', '--dry-run', action='store_true', help='list links but don\'t actually grab anything')
    group = parser.add_mutually_exclusive_group()
    group.add_argument('-O', '--overwrite', dest='existing', action='store_const', default='suffix', const='overwrite', help='overwrite existing files')
    group.add_argument('-s', '--skip', dest='existing', action='store_const', default='suffix', const='skip', help='skip existing files')
    parser.add_argument('-R', '--relative', action='store_true', help='keep path part of URL for local files')
    parser.add_argument('-S', '--strip-components', metavar='COMPONENTS', type=int, default=0, help='path components to strip with -R')
    parser.add_argument('-t', '--tor', action='store_true', default=('TOR' in os.environ), help='connect through Tor')
    parser.add_argument('urls', nargs=argparse.REMAINDER, help='URLs to scrape for docs')

    args = parser.parse_args()

    if len(args.extension) == 0:
        args.extension = ['.pdf']

    return args


def gather_links(urls, extensions, *, progress=False):
    count = 0
    for url in urls:
        req = requests.get(url, proxies=PROXIES)
        soup = bs4.BeautifulSoup(req.content, 'html.parser')
        links = [urllib.parse.urljoin(url, l.get('href')) for l in soup.find_all('a') if pathlib.Path(urllib.parse.urlparse(l.get('href', '')).path).suffix in extensions]
        if count == 0 and len(links) > 0 and progress:
            print('Documents linked:')
        for l in links:
            count += 1
            if progress:
                print(' [{}] {}'.format(count, l))
            yield l


def select_links(links):
    indices = range(len(links))
    valid = False
    while not valid:
        ans = input('Grab which docs? (* for all) ')
        if ans == '':
            # nothing
            valid = True
            indices = []
        elif ans == '*':
            # fine, get all links (default value for indices)
            valid = True
        else:
            ans = re.findall(r'[\w]+', ans)
            indices = []
            for a in ans:
                if not a.isdecimal():
                    print('Not a number: {}'.format(a))
                    break
                a = int(a) - 1
                if a < 0 or len(links) <= a:
                    print('Not in range: {}'.format(a))
                    break
                indices.append(a)
            else:
                # did not break: all valid!
                valid = True
    return indices


def grab_links(links, *, relative=False, existing='suffix', progress=False):
    for doc in links:
        if relative is not False:
            fnbase = pathlib.Path(urllib.parse.urlparse(doc).path)
            fnbase = pathlib.Path(os.path.sep.join(fnbase.parts[relative+1:]))  # add 1 to --strip-components value because .parts starts with a '/'
        else:
            fnbase = pathlib.Path(pathlib.Path(urllib.parse.urlparse(doc).path).name)
        filename = str(fnbase)
        if existing == 'suffix':
            count = 0
            while pathlib.Path(filename).exists():
                count = count + 1
                if count < 1000:
                    filename = fnbase.with_suffix('.{}{}'.format(count, fnbase.suffix))
                else:
                    print('Error: can\'t find a suitable name, skipped: {}'.format(doc), file=sys.stderr)
                    continue
        elif existing == 'skip':
            if pathlib.Path(filename).exists():
                print('File exists, skipped: {}'.format(doc))
                continue
        req = requests.get(doc, stream=progress, proxies=PROXIES)
        if req.status_code == 200:
            size = int(req.headers.get('content-length', 0))
            with open(filename, 'wb') as fd:
                if progress:
                    with tqdm.tqdm(total=size, unit='B', unit_scale=True, unit_divisor=1024, dynamic_ncols=True, desc='{} -> {}'.format(doc, filename)) as bar:
                        for chunk in req.iter_content(chunk_size=None):
                            fd.write(chunk)
                            bar.update(len(chunk))
                    # print(green('✓'))
                else:
                    fd.write(req.content)
        elif progress:
                print('{} -> {}: {} ({})'.format(doc, filename, red('✖'), req.status_code))


def main():
    args = parse_args()
    if args.tor:
        global PROXIES
        PROXIES = TOR

    # gather links
    links = list(gather_links(args.urls, args.extension, progress=True))
    if len(links) == 0 or args.dry_run:
        return 0
    print('')

    # select links
    indices = range(len(links)) if args.all else select_links(links)

    # grab links
    if len(indices):
        grab_links((links[i] for i in indices), relative=args.strip_components if args.relative else False, existing=args.existing, progress=True)
    else:
        print('No links grabbed.')


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print('\nCanceled.', file=sys.stderr)
