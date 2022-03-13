package App::corruptor;

use 5.010001;
use strict;
use warnings;
use Log::ger;

# AUTHORITY
# DATE
# DIST
# VERSION

our %SPEC;

my %argspec0_files = (
    files => {
        'x.name.is_plural' => 1,
        'x.name.singular' => 'file',
        schema => ['array*', of=>'filename*'],
        req => 1,
        pos => 0,
        slurpy => 1,
    },
);

$SPEC{corruptor} = {
    v => 1.1,
    summary => 'Corrupt files by writing some random bytes/blocks to them',
    description => <<'_',

This utility can be used in disk/filesystem testing. It corrupts files by
writing random bytes/blocks to them.

_
    args => {
        %argspec0_files,
        # XXX arg: block mode or byte mode
        proportion => {
            summary => 'How much random data is written '.
                'as proportion of file size (in percent)',
            schema => ['percent*', xmin=>0, max=>100],
            req => 1,
            cmdline_aliases => {p=>{}},
        },
    },
    features => {
        dry_run => 1,
    },
    examples => [
        {
            summary => 'Corrupt two files by writing 1% random bytes',
            argv => ['disk.img', 'disk2.img', '-p1%'],
            test => 0,
            'x.doc.show_result' => 0,
        },
    ],
    links => [
        {url=>'http://jrs-s.net/2016/05/09/testing-copies-equals-n-resiliency/'},
    ],
};
sub corruptor {
    my %args = @_;

    my $num_errors = 0;
    for my $file (@{$args{files}}) {
        unless (-f $file) {
            warn "corruptor: No such file '$file', skipped\n";
            $num_errors++;
            next;
        }
        my $filesize = -s _;
        unless ($filesize) {
            warn "corruptor: File '$file' is zero-sized, skipped\n";
        }
      WRITE:
        {
            log_info("Opening file '%s'", $file);
            open my $fh, "+<", $file or do {
                warn "corruptor: Can't open '$file': $!\n";
                $num_errors++;
                next;
            };
            my $n = int($filesize * $args{proportion});
            $n = 1 if $n < 1;
          CORRUPT:
            {
                if ($args{-dry_run}) {
                    log_info("[DRY] Writing %d random byte(s) to file ...", $n);
                    last CORRUPT;
                }
                log_info("Writing %d random byte(s) to file ...", $n);
                for (1..$n) {
                    my $pos = int(rand() * $filesize);
                    seek $fh, $pos, 0;
                    print $fh chr(rand() * 256);
                }
            }
            close $fh or do {
                warn "corruptor: Can't write '$file': $!\n";
                $num_errors++;
                next;
            };
        }
    }

    [$num_errors == @{$args{files}} ? 500 : 200,
     $num_errors == 0 ? "All OK" : $num_errors < @{$args{files}} ? "OK (some files failed)" : "All files failed",
     undef,
     {'cmdline.exit_code' => $num_errors ? 1:0}];
}

sub _corruptor {
    my ($which, %args) = @_;

    my $num_errors = 0;
    for my $file (@{$args{files}}) {
        unless (-f $file) {
            warn "corruptor-$which: No such file '$file', skipped\n";
            $num_errors++;
            next;
        }
        my $filesize = -s _;
        unless ($filesize) {
            warn "corruptor-$which: File '$file' is zero-sized, skipped\n";
        }
      WRITE:
        {
            log_info("Opening file '%s'", $file);
            open my $fh, "+<", $file or do {
                warn "corruptor: Can't open '$file': $!\n";
                $num_errors++;
                next;
            };
            seek $fh, 0, 0;
            for (1..$filesize) {
                if ($which eq 'total') {
                    print $fh chr(rand() * 256);
                } elsif ($which eq 'zero') {
                    print $fh "\0";
                } else {
                    die "BUG: Unknown destroy mode";
                }
            }
            close $fh or do {
                warn "corruptor-$which: Can't write '$file': $!\n";
                $num_errors++;
                next;
            };
        }
    }

    [$num_errors == @{$args{files}} ? 500 : 200,
     $num_errors == 0 ? "All OK" : $num_errors < @{$args{files}} ? "OK (some files failed)" : "All files failed",
     undef,
     {'cmdline.exit_code' => $num_errors ? 1:0}];
}

$SPEC{corruptor_total} = {
    v => 1.1,
    summary => 'Destroy files by replacing their contents with random data',
    args => {
        %argspec0_files,
    },
};
sub corruptor_total {
    my %args = @_;
    _corruptor('total', %args);
}

$SPEC{corruptor_zero} = {
    v => 1.1,
    summary => 'Destroy files by replacing their contents with zero bytes (nulls)',
    args => {
        %argspec0_files,
    },
};
sub corruptor_zero {
    my %args = @_;
    _corruptor('zero', %args);
}

1;
#ABSTRACT:
