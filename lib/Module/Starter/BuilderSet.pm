package Module::Starter::BuilderSet;

use strict;
use warnings;

use Carp qw( carp );

=head1 NAME

Module::Starter::BuilderSet - determine builder metadata

=head1 VERSION

Version 1.70

=cut

our $VERSION = '1.70';

=head1 SYNOPSIS

    use Module::Starter::BuilderSet;

    my $builder_set = Module::Starter::BuilderSet->new;
    my @supported_builders = $builder_set->supported_builders();
    my $default_builder = $builder_set->default_builder();
    my $output_file = $builder_set->file_for_builder($default_builder);

    my $create_method = $builder_set->method_for_builder($default_builder);
    Module::Starter::Simple->$create_method($default_builder); # eeew.

    my @build_commands = $builder_set->instructions_for_builder($default_builder);
    my @builder_dependencies = $builder_set->deps_for_builder($default_builder);
    my @compatible_builders = $builder_set->check_compatibility(@builder_list);

    my $ms_simple    = Module::Starter::Simple->new();
    my $build_method = $builder_set->manifest_method($builder);
    $ms_simple->$build_method();

=head1 DESCRIPTION

Module::Starter::BuilderSet is a collection of utility methods used to
provide metadata about builders supported by Module::Starter.

=head1 CLASS METHODS

=head2 C<< new() >>

This method initializes and returns an object representing the set of
Builders supported by Module::Starter

=cut

sub new {
    my $class = shift;

    my $self =
      {
       'Module::Build' =>
       {
        file           => "Build.PL",
        build_method   => "create_Build_PL",
        build_deps     => [],
        build_manifest => 'create_MB_MANIFEST',
        instructions   => [ 'perl Build.PL',
                            './Build',
                            './Build test',
                            './Build install',
                          ],
       },
       'Module::Install' =>
       {
        file           => "Makefile.PL",
        build_method   => "create_MI_Makefile_PL",
        build_deps     => [],
        build_manifest => 'create_MI_MANIFEST',
        instructions   => [ 'perl Makefile.PL',
                            'make',
                            'make test',
                            'make install',
                          ],
       },
       'ExtUtils::MakeMaker' =>
       {
        file           => "Makefile.PL",
        build_method   => "create_Makefile_PL",
        build_manifest => 'create_EUMM_MANIFEST',
        build_deps     => [ { command => 'make',
                              aliases => [ 'make', 'gmake' ],
                            },
                            { command => 'chmod',
                              aliases => [ 'chmod' ],
                            },
                          ],
        instructions   => [ 'perl Makefile.PL',
                            'make',
                            'make test',
                            'make install',
                          ],
       }
      };

    return bless $self, $class;
}

sub _builder {
    my $self = shift;
    my $builder = shift;

    $builder = $self->default_builder unless $builder;

    unless (exists $self->{$builder}) {
        carp("Don't know anything about builder '$builder'.");
        return;
    }

    return $self->{$builder};
}

=head2 C<< supported_builders() >>

This method returns a list of builders supported by Module::Starter

=cut

sub supported_builders {
    my $self = shift;

    return keys %$self;
}

=head2 C<< file_for_builder($builder) >>

This method returns the name of the file generated by Module::Starter
that will be used to build the generated module

=cut

sub file_for_builder {
    my $self = shift;
    my $builder = shift;

    return $self->_builder($builder)->{file};
}

=head2 C<< method_for_builder($builder) >>

This method returns the name of the method in the
C<Module::Starter::Simple> package that is called to create the file
returned by C<file_for_builder($builder)>

=cut

sub method_for_builder {
    my $self = shift;
    my $builder = shift;

    return $self->_builder($builder)->{build_method};
}

=head2 C<< instructions_for_builder($builder) >>

This method returns a list of commands that, when run from the command
line (or with C<system()>), will cause the generated module to be
built, tested and installed.

=cut

sub instructions_for_builder {
    my $self = shift;
    my $builder = shift;

    return @{ $self->_builder($builder)->{instructions} };
}

=head2 C<< deps_for_builder($builder) >>

This method returns a list of dependencies in the following format:
C<<
( { command => "make",
    aliases => [ 'make', 'gmake' ],
   },
  { command => "another_command",
    aliases => [ 'alias0', 'alias1', '...' ],
   },
)
>>

=cut

sub deps_for_builder {
    my $self = shift;
    my $builder = shift;

    return @{ $self->_builder($builder)->{build_deps} };
}

=head2 C<< manifest_method($builder) >>

This method returns the command to run to create the manifest according to the
builder asked.

=cut

sub manifest_method {
    my ( $self, $builder ) = @_;

    return $self->_builder($builder)->{'build_manifest'};
}

=head2 C<< check_compatibility(@builders) >>

This method accepts a list of builders and filters out the ones that
are unsupported or mutually exclusive, returning the builders that
passed the filter.  If none pass the filter, the default builder is
returned.

=cut

sub check_compatibility {
    my $self = shift;
    my @builders = @_;

    # if we're passed an array reference (or even a list of array
    # references), de-reference the first one passed and assign
    # @builders its contents

    @builders = @{$builders[0]} if(@builders && ref $builders[0] eq 'ARRAY');

    # remove empty and unsupported builders
    @builders = grep { $self->_builder($_) } @builders;

    # if we stripped all of them, use the default
    push(@builders, $self->default_builder) unless int( @builders ) > 0;

    my %uniq;
    my @good;
    foreach my $builder (@builders) {
        # Builders that generate the same build file are mutually exclusive

        # If given a list of builder modules that includes mutually
        # exclusive modules, we'll use the first in the list

        my $file = $self->file_for_builder($builder);
        if (exists $uniq{$file}) {
            # don't print a warning if the same builder was listed twice.
            # Otherwise, inform the caller that these builders are mutually
            # exclusive
            carp("Builders '$builder' and '$uniq{$file}' are mutually exclusive.".
                 "  Using '$uniq{$file}'."
                ) unless $builder eq $uniq{$file};
        } else {
            $uniq{$file} = $builder;
            push(@good, $uniq{$file});
        }
    }

    return( @good );
}

=head2 C<< default_builder() >>

This method returns the module name of the default builder.

=cut

sub default_builder {
    my $self = shift;

    return 'ExtUtils::MakeMaker';
}

=head1 BUGS

Please report any bugs or feature requests to the bugtracker for this project
on GitHub at: L<https://github.com/xsawyerx/module-starter/issues>. I will be
notified, and then you'll automatically be notified of progress on your bug
as I make changes.

=head1 AUTHOR

C.J. Adams-Collier, C<< <cjac@colliertech.org> >>

=head1 Copyright & License

Copyright 2007 C.J. Adams-Collier, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

Please note that these modules are not products of or supported by the
employers of the various contributors to the code.

=cut

1;

# vi:et:sw=4 ts=4
