#!/usr/bin/env python

import pexpect
import sys
import re
import os

'''This script creates mtrees replication between two Data Domain storages'''

#----EDIT THIS-----------VVVV
#source:

mtree_name='JJJJ'             #Mtree name - a non-existing one
source = 'x.x.x.x'     #external dd management address for source
username = 'xxxx'         #login name in DD for IP: 10.246.168.131
pswd = 'xxxx'             #password for the above login name

#destination:
destination ='x.x.x.x' #external dd management address for destination
username2 = 'xxxx'        #login name in DD for IP: 10.246.170.162
pswd2 = 'xxxx'        #password for the above login name


#----EDIT THIS-----------^^^^


#Log in  source DD---vvv

command='ssh sysadmin@' + source
print(command)
print('Logging in...')

try:
    child = pexpect.spawn(command)
    i = child.expect (['.*\r\nAccount locked.*', 'Password:','sysadmin@.*# '],timeout=30)
    if i == 0:
        print('Account locked. Can\'t login source DD')
        sys.exit()
    elif i == 1:
        child.sendline(pswd)
        child.expect('sysadmin@.*# ') 
    elif i == 2:
        print('Logged!')
except(pexpect.TIMEOUT):
    print('Can\'t login source DD')
    sys.exit()

#Log in  source DD---^^^



#Log in destination DD---vvv

command='ssh sysadmin@' + destination
print(command)
print('Logging in...')

try:
    child2 = pexpect.spawn(command)
    i = child2.expect (['.*\r\nAccount locked.*', '.*\r\nPassword:.*','sysadmin@.*# '],timeout=20)
    if i == 0:
        print('Account locked. Can\'t login target DD')
        sys.exit()
    elif i == 1:
        child2.sendline(pswd2)
        child2.expect('sysadmin@.*# ')
        print('Logged!')
    elif i == 2:
        print('Logged!')
except(pexpect.TIMEOUT):
    print('Can\'t login target DD')
    sys.exit()

#Log in destination DD---^^^


#Mtree list---vvvvvv
    
child.sendline ('hostname')
child.expect('sysadmin@.*# ')
result = re.findall(r'\w+\.\w+\.\w+', child.before)
print("Mtrees at source DD {0}:".format(result[0]))
child.sendline ('mtree list')
child.expect('sysadmin@.*# ')

mtree_list = child.before.splitlines()
for mtree_string in mtree_list:
    if re.findall(r'^\/data\/col1',mtree_string):
        print(mtree_string)

#Mtree list---^^^^^^

#Creating Mtree-------------------vvvvvv

command='mtree create /data/col1/' + mtree_name
child.sendline (command)
child.expect('sysadmin@.*# ')

#Creating Mtree-------------------^^^^^^

if re.findall(r'.*already exists\.',child.before):
    print('Mtree already exists! Set a new one.')
    child.sendline ('bye')
else:
    #defining src dd hostname
    command='hostname'
    child.sendline (command)
    child.expect('sysadmin@.*# ',timeout=30)
    hostname_src = re.findall(r'\w+\.\w+\.\w+\.\w+',child.before)
    print("Source hostname: {0}".format(hostname_src[0]))

    #defining trgt dd hostname    
    child2.sendline (command)
    child2.expect('sysadmin@.*# ',timeout=30)
    hostname_trgt = re.findall(r'\w+\.\w+\.\w+\.\w+',child2.before)
    print("Destination hostname: {0}".format(hostname_trgt[0]))
    
    if not hostname_trgt or  not hostname_src:
            print('Can\'t  get hostname(s). Exiting...')
            sys.exit()
    
    #setting replication context at src dd
    command='replication add source mtree://' + hostname_src[0] + '/data/col1/' + mtree_name + ' destination ' + 'mtree://' + hostname_trgt[0] + '/data/col1/' + mtree_name
    print(command)
    child.sendline (command)
    child.expect('sysadmin@.*# ',timeout=30)
    print ("To break replication: replication break mtree://{0}/data/col1/{1}".format(hostname_trgt[0],mtree_name))

    
    #setting replication context at trgt dd
    command='replication add source mtree://' + hostname_src[0] + '/data/col1/' + mtree_name + ' destination ' + 'mtree://' + hostname_trgt[0] + '/data/col1/' + mtree_name
    print(command)
    child2.sendline (command)
    child2.expect('sysadmin@.*# ',timeout=30)
    print ("To break replication: replication break mtree://{0}/data/col1/{1}".format(hostname_trgt[0],mtree_name))    
    
    
    #connectivity at src dd and trgt dd, and finally get replication initialized at src dd
    command="replication modify mtree://{0}/data/col1/{1} connection-host {2}".format(hostname_trgt[0], mtree_name, destination) 
    print(command)
    child.sendline (command)
    child.expect('sysadmin@.*# ',timeout=30)
    
    command="replication modify mtree://{0}/data/col1/{1} connection-host {2}".format(hostname_trgt[0], mtree_name, source) 
    print(command)    
    child2.sendline (command)
    child2.expect('sysadmin@.*# ',timeout=30)    

    command="replication initialize mtree://{0}/data/col1/{1}".format(hostname_trgt[0], mtree_name) 
    print(command)    
    child.sendline (command)
    child.expect('sysadmin@.*# ',timeout=30)    
    
    #Final parting words
    print ("\nCompleted!\n")
    message="To watch replication init: replication watch mtree://{0}/data/col1/{1}".format(hostname_trgt[0], mtree_name)
    print(message)
    message="To check out replication status: replication status mtree://{0}/data/col1/{1}".format(hostname_trgt[0], mtree_name)
    print(message)
    message="To export: nfs add /data/col1/{0}/tapelibNAME/DD1_POOL_FS1 192.168.128.0/17 (ro,no_root_squash,all_squash,secure,anonuid=88,anongid=88)".format(mtree_name)
    print(message)
    
    print("\nCleaning after self me - do the following on source and target data domain:\n")
    print("Break replication: replication break mtree://{0}/data/col1/{1}".format(hostname_trgt[0],mtree_name))
    print("Delete MTree: mtree delete /data/col1/{0}".format(mtree_name))
    print('File system clean up: filesys clean start')
    
child.sendline ('bye')
child2.sendline('bye')
