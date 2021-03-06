


package ExternalIdent;

use strict;

use Carp qw(croak);

use base 'Exporter';

our (@EXPORT_OK) = qw(VALID_IDENTIFIER generate_identifier %IDP);


# List the identifier prefixes:


our %IDP = ( URN => '(?:(?:urn[:]lsid[:])?(paleobiodb(?:[.]org[:])?|pbdb[:]|neotoma(?:[.]org)?[:]))',
	     TID => 'txn|var',
	     TXN => 'txn',
	     VAR => 'var',
	     OPN => 'opn',
	     REF => 'ref',
	     OCC => 'occ',
	     REI => 'rei',
	     SPM => 'spm',
	     MEA => 'mea',
	     COL => 'col',
	     INT => 'int',
	     TSC => 'tsc',
	     CLU => 'clu',
	     
	     SITE => 'sit',
	     CST => 'sit|col',
	     DST => 'dst',);


our %IDRE;
our %IDVALID;



# Construct regular expressions to validate the various identifier types, and
# then define a validator for each type.


my $key_expr = '';

foreach my $key ( keys %IDP )
{
    next if $key eq 'URN';
    $IDRE{$key} = qr{ ^ (?: $IDP{URN}? ( $IDP{$key} ) [:]? )? ( [0] | [1-9][0-9]* | ERROR ) $ }xsi;
    $IDVALID{$key} = sub { return valid_identifier(shift, shift, $key) };
    $key_expr .= '|' if $key_expr;
    $key_expr .= $IDP{$key};
}

$IDRE{ANY} = qr{ ^ (?: $IDP{URN}? ( $key_expr ) [:]? )? ( [0] | [1-9][0-9]* | ERROR ) $ }xsi;
$IDVALID{ANY} = sub { return valid_identifier(shift, shift, 'ANY') };

# VALID_IDENT ( type )
# 
# Return a closure which will validate identifiers of the given type.
# Acceptable values are any positive integer <n>, optionally preceded by the
# type, optionally preceded by the common URN prefix.  So, for example, each
# of the following are equivalent for specifying taxon number 23021:
# 
# 23021, txn23021, urn:paleobiodb.org:txn23021

sub VALID_IDENTIFIER {
    
    my ($type) = @_;
    
    croak "VALID_IDENTIFIER requires a parameter indicating the identifier type" unless $type;
    croak "No validator is defined for '$type'" unless ref $IDVALID{$type} eq 'CODE';
    
    return $IDVALID{$type};
    # return sub { return valid_identifier(shift, shift, $type) };
}


# valid_ident ( value, context, type )
# 
# Validator subroutine for paleobiodb.org identifiers.

sub valid_identifier {

    my ($value, $context, $type) = @_;
    
    # If the value matches the regular expression corresponding to the
    # specified type, then return the integer identifier extracted from it.
    # The rest of the value can be safely ignored.
    
    if ( $value =~ $IDRE{$type} )
    {
	my $domain = $1;
	my $type = $2;
	my $num = ($3 eq 'ERROR') ? -1 : $3;
	
	if ( $domain =~ /neotoma/ )
	{
	    return { value => Composite::ExtIdent->new('neotoma', $type, $num) };
	}
	
	elsif ( $domain =~ /pbdb|paleobio/ )
	{
	    return { value => Composite::ExtIdent->new('pbdb', $type, $num) };
	}
	
	elsif ( $domain eq '' )
	{
	    return { value => Composite::ExtIdent->new('', $type, $num) };
	}
	
	else
	{
	    return { error => "the value '{value}' of {param} is not recognized as " .
		     "an identifier from either Neotoma or PaleoBioDB" };
	}
    }
    
    # Otherwise, attempt to provide a useful error message.
    
    my $msg;
    
    if ( $type eq 'ANY' )
    {
	$msg = "each value of {param} must be a nonnegative integer, " .
	    "optionally prefixed with '$IDP{URN}xxx' where xxx is a valid identifier type (was {value})";
    }
    
    else
    {
	$msg = "each value of {param} must be a nonnegative integer, " .
	    "optionally prefixed with '$IDP{$type}' or '$IDP{URN}$IDP{$type}' (was {value})";
    }
    
    return { error => $msg };
}


# generate_ident ( type, id )
# 
# Generate a valid identifier of the specified type.  If the id is 0, then
# return the empty string.  If it is a positive integer, return the proper
# identifier string.  Otherwise, return an indication of a bad value.

sub generate_identifier {
    
    my ($domain, $type, $value) = @_;
    
    if ( defined $domain && $domain ne '' )
    {
	$domain .= ':';
    }
    
    else
    {
	$domain = '';
    }
    
    croak "you must specify an identifier type\n" unless $type;
    
    if ( ref $value eq 'ARRAY' )
    {
	map { $_ = defined $_ && $_ > 0 ? "$domain$IDP{$type}:$_" : "$domain$IDP{$type}:ERROR" } @$value;
    }
    
    elsif ( defined $value && $value > 0 )
    {
	return "$domain$IDP{$type}:$value";
    }
    
    elsif ( defined $value && $value eq '0' )
    {
	return '';
    }
    
    elsif ( defined $value && $value =~ qr{^U[A-Z]\d+$} )
    {
	return "$domain$IDP{$type}:$value";
    }
    
    elsif ( defined $value )
    {
	return "$domain$IDP{$type}:ERROR";
    }
    
    else
    {
	return;
    }
}


package Composite::ExtIdent;
use overload '""' => \&stringify, fallback => 1;

use Carp qw(croak);

sub new {
    
    my ($class, $domain, $type, $num) = @_;
    
    croak "bad call to new: missing arguments\n" unless defined $num && $num >= 0;
    
    $type = lc ($type // 'unk');
    
    my $new = { domain => $domain, type => $type, num => $num };
    
    $new->{taxon_no} = $num if $type eq 'var' || $type eq 'txn';
    
    return bless $new, $class;
}

sub stringify {
    
    my ($id) = @_;
    
    return $id->{num};
}

1;
