#!/usr/bin/env python

from prettytable import PrettyTable
from suds.client import Client
import argparse
import re
import sys

def barcode_type(s):
	s = s.upper()
	if not re.match('^[A-Z]{2}\d{9}[A-Z]{2}$', s) and not re.match('^\d{14}$', s):
		raise argparse.ArgumentTypeError('wrong barcode')
	return s

parser = argparse.ArgumentParser(description='Show tracking info from Russian Post service.')
parser.add_argument('barcode', type=barcode_type, help='item barcode')
args = parser.parse_args()

try:
	client = Client('http://voh.russianpost.ru:8080/niips-operationhistory-web/OperationHistory?wsdl')
	history = client.service.GetOperationHistory(Barcode=args.barcode, MessageType=0)
except Exception as e:
	sys.exit(e)

table = PrettyTable(['Date', 'Operation', 'Address', 'Weight'])
for row in history:
	date = operation = address = weight = ''

	try:
		date = row.OperationParameters.OperDate
	except:
		pass

	try:
		operation = row.OperationParameters.OperType.Name
		operation += ' (' + row.OperationParameters.OperAttr.Name + ')'
	except:
		pass

	try:
		address = row.AddressParameters.OperationAddress.Description
		address = row.AddressParameters.OperationAddress.Index + ' ' + address
	except:
		pass

	try:
		weight = row.ItemParameters.Mass
		weight /= 1000.0
	except:
		pass

	table.add_row([
		date,
		operation,
		address,
		weight,
	])

if hasattr(table, 'align'):
	table.align = 'l'
else:
	for field in table.fields:
		table.set_field_align(field, 'l')
print table.get_string()
