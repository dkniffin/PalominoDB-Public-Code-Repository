# 020_table_packer.t
# Copyright (C) 2013 PalominoDB, Inc.
# 
# You may contact the maintainers at eng@palominodb.com.
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use warnings FATAL => 'all';
use Test::More tests => 11;
use TestDB;
use English qw(-no_match_vars);
use Fcntl qw(:seek);
use DSN;

BEGIN {
  use_ok('TablePacker');
  my $tdb = TestDB->new();
  $tdb->use('table_packer');
  $tdb->dbh()->do(qq|
    CREATE TABLE `ibd_table` (
      `id`    INTEGER PRIMARY KEY AUTO_INCREMENT,
      `ts`    TIMESTAMP,
      `name`  VARCHAR(64) NOT NULL,
      `value` VARCHAR(100) NOT NULL
    ) Engine=InnoDB;
    |);
  $tdb->dbh()->do(qq|
    CREATE TABLE `ibd_table2` (
      `id`    INTEGER PRIMARY KEY AUTO_INCREMENT,
      `ts`    TIMESTAMP,
      `name`  VARCHAR(64) NOT NULL,
      `value` VARCHAR(100) NOT NULL
    ) Engine=InnoDB;
    |);
  $tdb->dbh()->do(qq|
    CREATE TABLE `myi_table` (
      `id`    INTEGER PRIMARY KEY AUTO_INCREMENT,
      `ts`    TIMESTAMP,
      `name`  VARCHAR(64) NOT NULL,
      `value` VARCHAR(100) NOT NULL
    ) Engine=MyISAM;
    |);
}

END {
  my $tdb = TestDB->new();
  $tdb->clean_db();
}

my $tdb = TestDB->new();
my $dsnp = DSNParser->default();
my $dsn_ibd1 = $dsnp->parse($tdb->dsn() . ",D=table_packer,t=ibd_table");
my $dsn_ibd2 = $dsnp->parse($tdb->dsn() . ",D=table_packer,t=ibd_table2");
my $dsn_nrl = $dsnp->parse($tdb->dsn() . ",D=table_packer,t=non_existant");
my $dsn_myi  = $dsnp->parse($tdb->dsn() . ",D=table_packer,t=myi_table");

my $tp_ibd1 = TablePacker->new($dsn_ibd1, $tdb->datadir(), $tdb->dbh());
my $tp_ibd2 = TablePacker->new($dsn_ibd2, $tdb->datadir(), $tdb->dbh());
my $tp_myi = TablePacker->new($dsn_myi, $tdb->datadir(), $tdb->dbh());
my $tp_nrl = TablePacker->new($dsn_nrl, $tdb->datadir(), $tdb->dbh());

is($tp_ibd1->engine(), 'innodb', 'engine type innodb');
is($tp_ibd1->format(), 'compact', 'row format compact');

ok($tp_myi->mk_myisam(), 'myisam -> myisam convert');
ok($tp_ibd1->mk_myisam(), 'innodb -> myisam convert');
is($tp_ibd1->engine(), 'myisam', 'innodb converts ok');

eval {
  $tp_ibd1->pack();
};
ok(!$EVAL_ERROR, 'table packs');
if($EVAL_ERROR) {
  diag('myisam out:', $tp_ibd1->{errstr});
  diag('EVAL ERROR:', $EVAL_ERROR);
}

eval {
  $tp_ibd1->flush();
};
ok(!$EVAL_ERROR, 'table flushes');
is($tp_ibd1->format(), 'compressed', 'table reports as compressed');
if($EVAL_ERROR) {
  diag('myisam out:', $tp_ibd1->{errstr});
}

eval {
  $tp_nrl->pack();
};
like($EVAL_ERROR, qr/^Error packing table.*/, 'dies when packing non-existant table');
if(!$EVAL_ERROR) {
  diag('myisam out:', $tp_nrl->{errstr});
}

eval {
  $tp_ibd2->mk_myisam();
  $tp_ibd2->pack();
  open(MYD_BARF, "+>", $tdb->datadir() . "/table_packer/ibd_table2.MYD") or die("Unable to open MYD");
  seek(MYD_BARF, 100, SEEK_SET);
  print(MYD_BARF "\000BARF\000\000\000\000");
  close(MYD_BARF);
  $tp_ibd2->check();
};
like($EVAL_ERROR, qr/^Error checking table.*/, 'dies when checking corrupt table');
if(!$EVAL_ERROR) {
  diag('myisam out:', $tp_ibd2->{errstr});
}
