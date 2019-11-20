#!/usr/bin/perl
use strict;
use warnings;
use Net::SSH::Perl;
use Socket;
#use Data::Dumper;
#use Term::ReadKey;

#==============================================
#19/10/2018
# This script creates mtrees replication between two Data Domain storages
#===============================================


#----EDIT THIS-----------VVVV
#source:
my $mtree_name='HHH';             #Mtree name - a non-existing one
my $source ='x.x.x.x';     #external dd management address for source 
my $username = "xxxx";        #login name in DD for IP: 10.246.168.131
my $pswd = "xxxx";            #password for the above login name

#destination:
my $destination='x.x.x.x'; #external dd management address for destination
my $username2 = "xxxx";       #login name in DD for IP: 10.246.170.162
my $pswd2 = "xxxx";       #password for the above login name

#----EDIT THIS-----------^^^^


my ($stdout, $stderr, $exit);
my $mtree='';
my $source_name='';
my $destination_name='';

my $ssh = Net::SSH::Perl->new($source, passphrase => $pswd, protocol => 2, interactive => 1, use_pty => 1, debug => 0);
$ssh->login($username, $pswd);

my $ssh2 = Net::SSH::Perl->new($destination, passphrase => $pswd2, protocol => 2, interactive => 1, use_pty => 1, debug => 0);
$ssh2->login($username2, $pswd2);

#-----------------------------------
#Listing Mtrees at source
#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

my $cmd = ('mtree list');
($stdout, $stderr, $exit) = $ssh->cmd($cmd);
print "$stdout\n";

my @values = split(/\n/, $stdout);
foreach my $val (@values) {
  if ($val =~ /^\/data\/col1/) {
   last;
  }
}

#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#Listing Mtrees at source
#-----------------------------------


#-----------------------------------
#Pausing a while to show menu
#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

print "Mtrees will be created in /data/col1\n";
print "Continue? (y/n):";
my $input = <>;
$input =~ s/[\n\r\f\t]//g;
$input =~ s/^\s+//;

unless ($input eq 'y')
{
exit;
}

#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#Pausing a while to show menu
#-----------------------------------



print "Mtree creating:\n";

#-----------------------------------
#Building Mtree at source
#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

$cmd = ("mtree create /data/col1/$mtree_name");
($stdout, $stderr, $exit) = $ssh->cmd($cmd);
print "$stdout\n";
print "to delete Mtree: mtree delete /data/col1/XXX\n";
print "to clean orphaned Mtree entries: filesys clean start\n";

#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#Mtree at source
#----------------------------------- 


#-----------------------------------
#Defining the  fully qualified dd hostname for a source and  destination
#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

$cmd = ("hostname");
($stdout, $stderr, $exit) = $ssh->cmd($cmd);
#print "$stdout\n";

if ($stdout =~ s/^The Hostname is: //) {
   $stdout =~ s/^\s+|\s+$//g;
   $source_name=$stdout;
  }
print "The source name: $source_name\n";


$cmd = ("hostname");
($stdout, $stderr, $exit) = $ssh2->cmd($cmd);

if ($stdout =~ s/^The Hostname is: //) {
   $stdout =~ s/^\s+|\s+$//g;
   $destination_name=$stdout;
  }
print "The destination name: $destination_name\n"; 
  
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#Defining the  fully qualified dd hostname for a source and a destination
#-----------------------------------  


#-----------------------------------
#Creating replication context at source and destination
#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

$cmd = ("replication add source mtree://$source_name/data/col1/$mtree_name destination mtree://$destination_name/data/col1/$mtree_name");
print "\n$cmd\n";
($stdout, $stderr, $exit) = $ssh->cmd($cmd);
print "To break replication: replication break mtree://$destination_name/data/col1/$mtree_name\n\n";


$cmd = ("replication add source mtree://$source_name/data/col1/$mtree_name destination mtree://$destination_name/data/col1/$mtree_name");
print "$cmd\n";
($stdout, $stderr, $exit) = $ssh2->cmd($cmd);
print "To break replication: replication break mtree://$destination_name/data/col1/$mtree_name\n\n";


#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#Creating replication context at source and destination
#-----------------------------------

#-----------------------------------
#Creating IP connectivity at source and destination, and finally getting it initiated at source
#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

$cmd = ("replication modify mtree://$destination/data/col1/$mtree_name connection-host $destination");
print "\n\n$cmd\n";
($stdout, $stderr, $exit) = $ssh->cmd($cmd);
print "To break replication: replication break mtree://$destination/data/col1/$mtree_name\n\n";


$cmd = ("replication modify mtree://$destination/data/col1/$mtree_name connection-host $source");
print "$cmd\n";
($stdout, $stderr, $exit) = $ssh2->cmd($cmd);
print "To break replication: replication break mtree://$destination/data/col1/$mtree_name\n\n";


$cmd = ("replication initialize mtree://$destination_name/data/col1/$mtree_name");
print "Now wait...\n\n";
print "$cmd\n";
($stdout, $stderr, $exit) = $ssh->cmd($cmd);

#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#Creating IP connectivity at source and destination, and final initiating it at source
#-----------------------------------

print "\nCompleted\n\n";
print "To watch replication init: replication watch mtree://$destination_name/data/col1/$mtree_name\n";
print "Replication status: replication status mtree://$destination_name/data/col1/$mtree_name\n\n";
print "To delete:\n\n";
print "At destination: replication break  mtree://$destination_name/data/col1/$mtree_name\n";
print "At destination: mtree delete  /data/col1/$mtree_name\n";
print "At destination: filesys clean start\n\n";

print "At source: replication break  mtree://$destination_name/data/col1/$mtree_name\n";
print "At source: mtree delete  /data/col1/$mtree_name\n\n";
print "At source: filesys clean start\n\n";

print "To export: nfs add /data/col1/$mtree_name/tapelibNAME/DD1_POOL_FS1 192.168.128.0/17 (ro,no_root_squash,all_squash,secure,anonuid=88,anongid=88)\n";


