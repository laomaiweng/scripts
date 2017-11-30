#!/usr/bin/env python3

import bs4
import requests


def main():
    ''' Reach out to check.torproject.org to check for Tor. '''
    req = requests.get('https://check.torproject.org')
    if req.status_code == 200:
        soup = bs4.BeautifulSoup(req.content, 'html.parser')
        result = soup.find(class_='not')
        if result:
            print(result.text.strip())
        else:
            print('You do not seem to be using Tor.')
    else:
        print('Cannot reach check.torproject.org.')


if __name__ == '__main__':
    main()
