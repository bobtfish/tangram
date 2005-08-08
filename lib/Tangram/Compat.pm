
# package for compatilibity with older Tangram APIs.

# first major change: Tangram::Scalar => Tangram::Type::Scalar, etc

package Tangram::Compat;

use Tangram::Compat::Stub;

use constant REMAPPED =>
    qw( Tangram::Scalar			Tangram::Type::Scalar
	Tangram::RawDate		Tangram::Type::Date::Raw
	Tangram::String			Tangram::Type::String
	Tangram::Integer		Tangram::Type::Integer
	Tangram::Real			Tangram::Type::Real
	Tangram::Number			Tangram::Type::Number
	Tangram::AbstractSet		Tangram::Type::Abstract::Set
	Tangram::AbstractHash		Tangram::Type::Abstract::Hash
	Tangram::AbstractArray		Tangram::Type::Abstract::Array
	Tangram::Coll			Tangram::Type::Abstract::Coll
	Tangram::Alias			Tangram::Expr::TableAlias
	Tangram::CollCursor		Tangram::Cursor::Coll
      );

use strict 'vars', 'subs';
use Carp qw(cluck confess croak carp);

sub DEBUG() { 0 }
sub debug_out { print STDERR __PACKAGE__.": @_\n" }

our $stub;
BEGIN { $stub = $INC{'Tangram/Compat/Stub.pm'} };

# this method is called when you "use" something.  This is a "Chain of
# Command Patte<ETOOMUCHBS>

sub Tangram::Compat::INC {
    my $self = shift;
    my $fn = shift;

    (my $pkg = $fn) =~ s{/}{::}g;
    $pkg =~ s{.pm$}{};

    (DEBUG) && debug_out "saw include for $pkg";

    if ($self->{map}->{$pkg}) {
	$self->setup($pkg);
	open DEVNULL, "<$stub" or die $!;
	return \*DEVNULL;
    }
    else {
	return undef;
    }
}

sub setup {
    debug_out("setup(@_)") if (DEBUG);
    my $self = shift;
    my $pkg = shift or confess ("no pkg!");
    undef &{"${pkg}::AUTOLOAD"};
    my $target = delete $self->{map}{$pkg};
    confess "no target package" unless $target;

    carp "deprecated package $pkg used by ".caller().", auto-loading $target";

    debug_out("using $target") if (DEBUG);
    #kill 2, $$;
    eval "use $target";
    #kill 2, $$;
    debug_out("using $target yielded \$\@ = '$@'") if DEBUG;
    die $@ if $@;
    #kill 2, $$;
    #my $eval = "package $pkg; \@ISA = qw($target)";
    #debug_out("creating $pkg with: $eval") if (DEBUG);
    #eval $eval; die $@ if $@;
    #$
    @{"${pkg}::ISA"} = $target;
    #debug_out("creating package yielded \$\@ = '$@'") if DEBUG;
    if ( @_ ) {
	my $method = shift;
	($pkg, $method) = $method =~ m{(.*)::(.*)};
	@_ = @{(shift)};
	my $code = $pkg->can($method)
	    or do {
		debug_out("pkg is $pkg, its ISA is ".join(",",@{"${pkg}::ISA"})) if (DEBUG);
		croak "$pkg->can't($method)";
	    };
	debug_out("Calling $pkg->$method(@_)") if DEBUG;
	goto $code;
    }
}

our $AUTOLOAD;

sub new {
    my $inv = shift;
    my $self = bless { map => { @_ },
		     }, (ref $inv||$inv);
    for my $pkg ( keys %{$self->{map}} ) {
	debug_out "setting up $pkg => $self->{map}{$pkg}" if DEBUG;

	*{"${pkg}::AUTOLOAD"} = sub {
	    return if $AUTOLOAD =~ /::DESTROY$/;
	    debug_out "pkg is $pkg, AUTOLOAD is $AUTOLOAD" if DEBUG;
	    my $stack = [ @_ ];
	    @_ = ($self, $pkg, $AUTOLOAD, $stack);
	    goto &setup;
	};
    }
    return $self;
}

sub DESTROY {
    my $self = shift;
    @INC = grep { defined and 
		      (!ref($_) or refaddr($_) ne refaddr($self)) }
	@INC;
}

use Devel::Symdump;
BEGIN {
    my $loader = __PACKAGE__->new(REMAPPED);
    #unshift @INC, __PACKAGE__->new( REMAPPED );
    #print STDERR "INC is now: @INC\n";
    #my $sd = Devel::Symdump->new("Tangram::Compat");
    #print STDERR "Compat is: ".$sd->as_string;
    unshift @INC, $loader;
}

1;
