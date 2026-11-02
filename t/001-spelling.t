# DO NOT EDIT! This file is written by perl_setup_dist.
# If needed, you can add content at the end of the file.

#!/usr/bin/perl

use strict;
use warnings;

use Test2::V0;

use English;
use File::Basename 'basename', 'dirname';
use File::Find 'find';
use File::Spec::Functions 'abs2rel';
use FindBin;

our $VERSION = 0.03;

BEGIN {
  if ($ENV{HARNESS_ACTIVE} && !$ENV{EXTENDED_TESTING}) {
    skip_all('Extended test. Run manually or set $ENV{EXTENDED_TESTING} to a true value to run.');
  }
}

BEGIN {
  eval 'use IPC::Run3';  ## no critic (ProhibitStringyEval, RequireCheckingReturnValueOfEval)
  if ($EVAL_ERROR) {
    my $msg = 'IPC::Run3 required to spell check code';
    skip_all($msg);
  }
}

my $aspell = `which aspell 2> /dev/null`;  ## no critic (ProhibitBacktickOperators)

my $root = $FindBin::Bin.'/..';

my $mode = (@ARGV && $ARGV[0] eq '--interactive') ? 'interactive' : 'list';

my @base_cmd = (
  'aspell', '--encoding=utf-8', "--home-dir=${root}", '--dont-backup',
  '--lang=en', '-p', '.aspelldict'
);

# For some reasons, the --mode=perl option of Aspell does not work correctly (in
# all cases, it would not handle POD content). so we are passing manually the
# options to the "context" filters underlying the perl mode.
my %lang_filter = (
  html => ['--mode=sgml'],
  markdown => ['--mode=markdown'],
  perl => [
    '--mode=none', '--add-filter=url',
    '--add-filter=context', '--clear-context-delimiters',
    '--add-context-delimiters==pod =cut', '--add-context-delimiters=# \0',
    '--add-context-delimiters=" "', "--add-context-delimiters=' '"
  ]
);

if (not $aspell) {
  skip_all('The aspell program is required in the path to check the spelling.');
}

# Returns the list of the misspelled words of the given file, without
# duplicates, in their order of appearance.
sub list_bad_words {
  my ($file, $type) = @_;
  my $bad_words;
  my @cmd = (@base_cmd, @{$lang_filter{$type}}, 'list');
  run3(\@cmd, $file, \$bad_words) or die "Can’t run aspell: $!\n";
  my %seen;
  return grep { length && !$seen{$_}++ } split /\n/, $bad_words;
}

# Prints the given misspelled words of the given file, with the numbers of the
# lines where they appear, so that they can be found and fixed (or added to
# the .aspelldict file).
sub diag_bad_words {
  my ($file, $file_from_root, @words) = @_;
  open my $fh, '<', $file or die "Can’t open ${file}: $!\n";
  my @lines = <$fh>;
  close $fh or die "Can’t close ${file}: $!\n";
  for my $w (@words) {
    # Aspell splits words on anything that is not a letter (e.g. on '_').
    my @numbers =
        grep { $lines[$_ - 1] =~ m/(?<![[:alpha:]]) \Q${w}\E (?![[:alpha:]])/x } 1 .. @lines;
    my $where = q{};
    $where = sprintf ' at line%s %s', (@numbers > 1 ? 's' : q{}), join(', ', @numbers) if @numbers;
    diag("Unknown word '${w}' in ${file_from_root}${where}");
  }
  diag('Fix these words or add them to the .aspelldict file.');
  return;
}

sub interactive_check {
  my ($file, $type) = @_;
  my @cmd = (@base_cmd, @{$lang_filter{$type}}, 'check', $file);
  return system @cmd;
}

# Note: while strings in Perl modules are checked, the POD content is ignored
# unfortunately.

# The directories that are not spell-checked, in addition to the hidden ones.
my %skipped_dirs = map { $_ => 1 } qw(blib third_party pod2html build cover_db nytprof local);

sub wanted {
  # We should do something more generic to not recurse in Git sub-modules.
  $File::Find::prune = 1 if -d && ($skipped_dirs{$_} || m/^ [.] . /x);
  return unless -f;

  my $type;
  if (m/\.(?:pm|pod)$/ || basename($File::Find::dir) eq 'script') {
    $type = 'perl';
  } elsif (m/\.md$/) {
    $type = 'markdown';
  } elsif (m/\.html$/) {
    $type = 'html';
  } else {
    return;
  }

  my $file_from_root = abs2rel($File::Find::name, $root);
  if ($mode eq 'list') {
    my @bad_words = list_bad_words($_, $type);
    ok(!@bad_words, "Spell-checking ${file_from_root} (${type})")
        or diag_bad_words($_, $file_from_root, @bad_words);
  } elsif ($mode eq 'interactive') {
    is(interactive_check($_, $type),
      0, "Interactive spell-checking for ${file_from_root} (${type})");
  } else {
    die "Unknown operating mode: '${mode}'";
  }

  return;
}

find(\&wanted, $root);
done_testing();

# End of the template. You can add custom content below this line.
