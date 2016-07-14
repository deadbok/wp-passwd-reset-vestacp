# -*- coding: utf-8 -*-
"""
Update the secrets in a Wordpress configuration file.

MIT License

Copyright (c) 2016 Martin Bo Kristensen Grønholdt 

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE
"""
from __future__ import print_function

import glob
import argparse
import os.path
import base64
import M2Crypto


def print_welcome():
	"""
	Print welcome message.
	"""
	print("Changing WordPress password and salt.")
	

def change_value(value, config, start):
	"""
	Change a config value with define PHP syntax.
	"""
	for i in range(0, len(config)):
		line = config[i].replace(' ', '');
		line = line.replace('\t', '');
		if line.startswith(start):
			config[i] = line[:len(start) - 1] + " '" + value + "');\n"
			print('.', end='')
			return
	print('e', end='')
	exit('Error changing value for: ' + start)
	

def generate_salt(length = 64):
	return base64.b64encode(M2Crypto.m2.rand_bytes(length))
	
	
def main():
	arg_parser = argparse.ArgumentParser()
	arg_parser.add_argument("config_file", type=argparse.FileType('rw+'), 
						help="Path the WordPress configuration file to change the password and salts for.")
	arg_parser.add_argument("-n", "--name", dest="name", default=None, 
						help="The WordPress database name.")
	arg_parser.add_argument("-u", "--user", dest="user", default=None, 
						help="The WordPress database user.")
	arg_parser.add_argument("-p", "--pass", dest="passwd", default=None, 
						help="The WordPress database password.")
	arg_parser.add_argument("-s", "--salts", action="store_true", default=False, 
						help="Change the WordPress salts.")
	arg_parser.add_argument("-b", "--backup", action="store_true", default=False, 
						help="Backup the current WordPress configuration file.")

		
	args = arg_parser.parse_args()
	print_welcome()
	
	if args.config_file is None:
		exit('Error opening configuration file.')
	
	config = args.config_file.readlines()
	if (len(config) == 0):
		exit('Error, empty configuration file.')
		
	try:
		if (args.backup):
			filename = args.config_file.name + '.bak'
			with open(filename, 'w') as backup:
				backup.write(''.join(config))
				backup.close()
				print('Original WordPress config saved as: ' + filename)
	except Exception as ex:
		exit('Error creating backup: ' + str(ex))
		
	
	if args.user is not None:
		if args.user != '':
			print('Changing user: "' + args.user + '"', end='')
			change_value(args.user, config, "define('DB_USER','")
			print
	if args.passwd is not None:
		if (args.passwd != ''):
			print('Changing password: "' + args.passwd + '"', end='')
			change_value(args.passwd, config, "define('DB_PASSWORD','")
			print('')
	if args.name is not None:
		if (args.name != ''):
			print('Database name: "' + args.name + '"', end='')
			change_value(args.name, config, "define('DB_NAME','")
			print

	if args.salts is not None:
		if (args.salts):
			print('Changing salts.', end='')
			change_value(generate_salt(), config, "define('AUTH_KEY','")
			change_value(generate_salt(), config, "define('SECURE_AUTH_KEY','")
			change_value(generate_salt(), config, "define('LOGGED_IN_KEY','")
			change_value(generate_salt(), config, "define('NONCE_KEY','")
			change_value(generate_salt(), config, "define('AUTH_SALT','")
			change_value(generate_salt(), config, "define('SECURE_AUTH_SALT','")
			change_value(generate_salt(), config, "define('LOGGED_IN_SALT','")
			change_value(generate_salt(), config, "define('NONCE_SALT','")

	print
	print('done')
	
	args.config_file.seek(0)	
	args.config_file.write(''.join(config))
	args.config_file.close()


if __name__ == '__main__':
	main()
