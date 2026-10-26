#!/usr/bin/perl

# Tests the --pack and --export flags, where fragments are embedded in the
# script itself.

use strict;
use warnings;

use Test2::V0;

use File::Path 'make_path';
use File::Spec::Functions 'catfile';
use FindBin;
use lib "${FindBin::Bin}/lib";
use UpdateConfigTest 'guarded';

our $VERSION = 0.01;

# Returns the path of a packed script containing the given fragments.
sub pack_fragments {
  my (%fragments) = @_;
  my $t = UpdateConfigTest->new;
  $t->add_fragment($_, $fragments{$_}) for keys %fragments;
  # We run from another directory to check that the script finds itself.
  my $r = $t->run({cwd => $t->home}, '--pack');
  is($r->{exit}, 0, '--pack: success');
  is($t->read_home_file($_), undef, "--pack: ${_} not written") for keys %fragments;
  my $packed = catfile($t->root, 'packed.pl');
  UpdateConfigTest::write_file($packed, $r->{stdout});
  return ($packed, $t);
}

{
  my ($packed) = pack_fragments(
    'file' => "content\n",
    'sub/other' => "FILENAME .other\nother\n",
    'overridden' => "packed\n");
  my $t = UpdateConfigTest->new;
  $t->add_fragment('overridden', "local\n");
  my $r = $t->run({stdin => $packed});
  is($r->{exit}, 0, 'packed script: success');
  is($t->read_home_file('file'), guarded("content\n"), 'packed fragment applied');
  is($t->read_home_file('.other'),
    guarded("other\n"), 'packed fragment from a sub-directory applied');
  is($t->read_home_file('overridden'),
    guarded("local\n"), 'local fragment overrides packed fragment');
}

{
  my ($packed) = pack_fragments('root_file' => "NEED ROOT\nroot\n");
  my $t = UpdateConfigTest->new;
  my $r = $t->run({stdin => $packed});
  is($r->{exit}, 0, 'NEED ROOT from stdin: success');
  like(
    $r->{stdout},
    qr/^Skipping[ ]NEED_ROOT[ ]fragments[ ]for[ ]an[ ]execution/mx,
    'NEED ROOT from stdin: skipped');
  is($t->read_home_file('root_file'), undef, 'NEED ROOT from stdin: not written');
  $r = $t->run({stdin => $packed}, '--pack');
  isnt($r->{exit}, 0, '--pack from stdin: failure');
}

{
  my ($packed, $t) =
      pack_fragments('in,out' => "content\n", 'other [x]' => "FILENAME .bar\nother\n");
  my $export_dir = catfile($t->root, 'export');
  make_path($export_dir);
  my $r = $t->run({script => $packed, cwd => $export_dir}, '--export');
  is($r->{exit}, 0, '--export: success');
  # The packed fragments have an extra empty line at the end, which is ignored
  # when they are applied.
  like(
    UpdateConfigTest::read_file(catfile($export_dir, 'in_out')),
    qr/\AFILENAME[ ]in,out\ncontent\n+\z/x,
    '--export: FILENAME added and name cleaned');
  like(
    UpdateConfigTest::read_file(catfile($export_dir, 'other [x]')),
    qr/\AFILENAME[ ][.]bar\nother\n+\z/x,
    '--export: existing FILENAME kept');
}

done_testing;
