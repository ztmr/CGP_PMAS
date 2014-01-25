#!/usr/bin/env perl
#
# $Id: $
#
# Module:  RPMAS -- Remote PMAS processor tool
# Created: 16-DEC-2009 11:17
# Author:  TMR
#

use strict;
use warnings;

use Digest::SHA qw(sha1_hex);
use Net::IMAP::Simple;

our %CONFIG = (
  server    => 'mail.example.org',
  username  => 'pmas',
  password  => '<supersecret of your PMAS account in CGP>',
  folder    => 'INBOX',
  msgremove => 1, # 1 to remove, 0 not to remove
  processor => '@PMAS_COM:SPAM_PROCESS.COM',
  tmpfilpfx => 'PMAS_ROOT:[TMP]RPMAS_',
  isvms     => 1
);

eval ("use VMS::Stdio;");
$CONFIG{isvms} = 0 if $@;

sub mydie {

  print "@_\n";
  exit; # VMS doesn't like to return any specific error code...
}

sub mktmpfil {
  my ($fnam, $content) = @_;

  open (FW, ">$fnam")
    or &mydie ('%PMAS-W-FILOPEN, cannot create/write '.$fnam.' file');
  foreach my $ln (@$content) {
    $ln =~ s/\r\n/\n/g;  # If we run on VMS, the EoLn conversion is needed
    print FW $ln;
  }
  close (FW);
}

sub process {

  my ($server, $msgcnt) = @_;

  foreach my $msg (0 .. $msgcnt -1) {

    $msg += 1;
    next if ($server->seen ($msg));

    my $fh = $server->getfh ($msg);
    my $ln = $server->get ($msg);
    my $tmpfil = $CONFIG{tmpfilpfx}.&sha1_hex (@$ln);
    &mktmpfil ($tmpfil, $ln);
    close ($fh);

    #printf ("$CONFIG{processor} $tmpfil\n");
    `$CONFIG{processor} $tmpfil`;

    unlink ($tmpfil);
    $server->delete ($msg) if ($CONFIG{msgremove});
  }
}

my $server = new Net::IMAP::Simple ($CONFIG{server});

eval {
  #if ($server->login ($CONFIG{username}, $CONFIG{password})) {
  $server->login ($CONFIG{username}, $CONFIG{password});

    my $msgcnt = $server->select ($CONFIG{folder}) || 0;
    &process ($server, $msgcnt);
    $server->quit ();
  #}
  #else {
  #  &mydie ('%RPMAS-E-IVLOGIN, cannot login using your credentials');
  #}
};
print $@ if ($@);

# vim: fdm=syntax:fdn=3:tw=74:ts=2:syn=perl
