package CATS::Formal::Generators::Testlib;
use strict;
use warnings;

use BaseGenerator; 
use lib '..';
use Constants qw(FD_TYPES);

use parent -norequire, 'CATS::Formal::Generators::BaseGenerator';

use constant FD_TYPES => CATS::Formal::Constants::FD_TYPES;
use constant TOKENS   => CATS::Formal::Constants::TOKENS;
use constant PRIORS   => CATS::Formal::Constants::PRIORS;

use constant BAD_NAMES => {
    alignas => 1, 
    alignof => 1,
    and     => 1,
    and_eq  => 1,
    asm     => 1,
    auto    => 1,
    bitand  => 1,
    bitor   => 1,
    bool    => 1,
    break   => 1,
    case    => 1,
    catch   => 1,
    char    => 1,
    char16_t=> 1,
    char32_t=> 1,
    class   => 1,
    compl   => 1,
    const   => 1,
    constexpr=> 1,
    const_cast=> 1,
    continue=> 1,
    decltype=> 1,
    default => 1,
    delete  => 1,
    do      => 1,
    double  => 1,
    dynamic_cast=> 1,
    else    => 1,
    enum    => 1,
    explicit=> 1,
    export  => 1,
    extern  => 1,
    false   => 1,
    float   => 1,
    for     => 1,
    friend  => 1,
    goto    => 1,
    if      => 1,
    inline  => 1,
    int     => 1,
    long    => 1,
    mutable => 1,
    namespace=> 1,
    new     => 1,
    noexcept=> 1,
    not     => 1,
    not_eq  => 1,
    nullptr => 1,
    operator=> 1,
    or      => 1,
    or_eq=> 1,
    private=> 1,
    protected=> 1,
    public=> 1,
    register=> 1,
    reinterpret_cast=> 1,
    return=> 1,
    short=> 1,
    signed=> 1,
    sizeof=> 1,
    static=> 1,
    static_assert=> 1,
    static_cast=> 1,
    struct=> 1,
    switch=> 1,
    template=> 1,
    this=> 1,
    thread_local=> 1,
    throw => 1,
    true => 1,
    try => 1,
    typedef => 1,
    typeid => 1,
    typename => 1,
    union => 1,
    unsigned => 1,
    using => 1,
    virtual => 1,
    void => 1,
    volatile => 1,
    wchar_t => 1,
    while => 1,
    xor => 1,
    xor_eq => 1,
};

my $struct_counter = 0;
#$self->{description} = {
#   def_name => {real_name=>'', type=>$self->{types}}    
#}
my $stream_name = '__in__stream__';

sub generate {
    my ($self, $obj) = @_;
    $self->{names} = {};
    $self->{type_definitions} = '';
    $self->{type_declarations} = '';
    $self->{definitions} = {};
    $self->{reader} = '';
    $self->generate_description($obj);
    return <<"END"
#include "testlib.h"
#define assert(C) if (!(C)){printf("assert failed at %d", __LINE__); exit(1);}

using namespace std;

$self->{type_declarations}

$self->{declarations}

$self->{type_definitions}

void read_all(InStream& $stream_name){
$self->{reader}
}

int main(){
    registerValidation();
    inf.strict = false;
    read_all(inf);
    inf.readEoln();
    inf.readEof();
    return 0;
}
END

}

sub generate_int_obj {
    my ($self, $fd, $prefix, $deep) = @_;
    my $obj = {};
    my $spaces = '    ' x $deep;
    $obj->{name} = $self->find_good_name($fd->{name} || '_tmp_obj_');
    $obj->{name_for_expr} = $prefix . $obj->{name};
    $obj->{reader} = $spaces . "$obj->{name_for_expr} = $stream_name.readLong();\n";
    $obj->{declaration} = "long long $obj->{name};\n";
    $fd->{obj} = $obj;
    return $obj;
}

sub generate_float_obj {
    my ($self, $fd, $prefix, $deep) = @_;
    my $obj = {};
    my $spaces = '    ' x $deep;
    $obj->{name} = $self->find_good_name($fd->{name} || '_tmp_obj_');
    $obj->{name_for_expr} = $prefix . $obj->{name};
    $obj->{reader} = $spaces."$obj->{name_for_expr} = $stream_name.readDouble();\n";
    $obj->{declaration} = "double $obj->{name};\n";
    $fd->{obj} = $obj;
    return $obj;
}


sub generate_string_obj {
    my ($self, $fd, $prefix, $deep) = @_;
    my $obj = {};
    my $spaces = '    ' x $deep;
    $obj->{name} = $self->find_good_name($fd->{name} || '_tmp_obj_');
    $obj->{name_for_expr} = $prefix . $obj->{name};
    $obj->{reader} = $spaces . "$obj->{name_for_expr} = $stream_name.readString();\n";
    $obj->{declaration} = "string $obj->{name};\n";
    $fd->{obj} = $obj;
    return $obj;
}

sub generate_seq_obj {
    my ($self, $fd, $prefix, $deep) = @_;
    my $obj = {};
    my $spaces = '    ' x $deep;
    $obj->{name} = $self->find_good_name($fd->{name} || '_tmp_obj_');
    $obj->{name_for_expr} = $prefix . $obj->{name};
     
    my $type = "SEQ_$struct_counter";
    my $seq_elem = $self->find_good_name($type.'_elem');
    
    $struct_counter++;
    $obj->{declaration} = "vector<$type> $obj->{name};\n";
    my $members = '';
    my $len = $fd->{attributes}->{length};
    if ($len) {
        my $e = generate_expr($len);
        $obj->{reader} = $spaces."while($obj->{name_for_expr}.size() < $e){\n";
    } else {die "not implemented"}
    
    $obj->{reader} .= "$spaces    $type $seq_elem;\n";
    
    foreach my $child (@{$fd->{children}}){
        my $child_obj = $self->generate_obj($child, "$seq_elem.", $deep + 1);
        $obj->{reader} .= $child_obj->{reader};
        $members .= $child_obj->{declaration};
    }
    $obj->{reader} .= $spaces."    $obj->{name_for_expr}.push_back($seq_elem);\n";
    $obj->{reader} .= $spaces."}\n";
    
    my $struct_definition = <<"END"    
struct $type {
    $members
};

END
;
    $self->{type_declarations} .= "struct $type;\n"; 
    $self->{type_definitions} .= $struct_definition;
    
    $fd->{obj} = $obj;
    return $obj;
}

sub generate_obj {
    my ($self, $fd, $prefix, $deep) = @_;
    my $gens = {
        FD_TYPES->{INT} => \&generate_int_obj,
        FD_TYPES->{FLOAT} => \&generate_float_obj,
        FD_TYPES->{STRING} => \&generate_string_obj,
        FD_TYPES->{SEQ} => \&generate_seq_obj,
    };
    my $gen = $gens->{$fd->{type}};
    return $self->$gen($fd, $prefix, $deep);
}

sub generate_description {
    my ($self, $fd) = @_;
    if ($fd->{type} == FD_TYPES->{ROOT}) {
        my $input = $fd->find_child_by_type(FD_TYPES->{INPUT});
        foreach my $child (@{$input->{children}}){
            my $obj = $self->generate_obj($child, '', 1);
            $self->{reader} .= $obj->{reader};
            $self->{declarations} .= $obj->{declaration};
        }
        return;
    } else { die "not implemented" };
}

sub find_good_name {
    my ($self, $name) = @_;
    while (BAD_NAMES->{$name} || $self->{names}->{$name}) {
        $name = "_$name" . '_';
    }
    #$self->{names}->{$name} = 1;
    return $name;
}

sub op_to_code {
    my $op = shift;
    {
        TOKENS->{NOT}   => '!',
        #TOKENS->{POW}   => ,
        TOKENS->{MUL}   => '*',
        TOKENS->{DIV}   => '/',
        TOKENS->{MOD}   => '%',
        TOKENS->{PLUS}  => '+',
        TOKENS->{MINUS} => '-',
        TOKENS->{LT}    => '<',
        TOKENS->{GT}    => '>',
        TOKENS->{EQ}    => '==',
        TOKENS->{NE}    => '!=',
        TOKENS->{LE}    => '<=',
        TOKENS->{GE}    => '>=',
        TOKENS->{AND}   => '&&',
        TOKENS->{OR}    => '||',
    }
}

sub generate_expr {
    my $expr = shift;
    if ($expr->is_binary) {
        my $left = generate_expr($expr->{left});
        my $right = generate_expr($expr->{right});
        if ($expr->{op} == TOKENS->{POW}) {
            return "pow($left, $right)";
        }
        return "($left " . op_to_code($expr->{op}) . " $right)";
    } elsif ($expr->is_unary) {
        my $node = generate_expr($expr->{node});
        return '('.op_to_code($expr->{op}) . "$node)";
    } elsif ($expr->is_variable) {
        return $expr->{fd}->{obj}->{name_for_expr};
    } elsif ($expr->is_array){
        die "not implemented";
    
    
    } elsif ($expr->is_string) {
        my $s = $$expr;
        return "\"$s\"";
    } elsif ($expr->is_constant) {
        return $$expr;
    } elsif ($expr->is_function) {
        my $params = join ',' , (map generate_expr($_), @{$expr->{params}});
        return "$expr->{name}($params)";
    } elsif ($expr->is_member_access) {
        die "not implemented";
    
    
    } elsif ($expr->is_array_access) {
        return generate_expr($expr->{head}) . '[' . generate_expr($expr->{index}) . ']';
    } else {die "wtf"}
    
}

<<END

/**
int name=A;
seq name=C, length=A;
    seq name=B, length=A;
        int name=A;
        assert A == length(B);
    end;
end;
*/

#include "testlib.h"
#defint assert(C) if (!(C)){printf("assert failed at %d, __LINE__); exit(1);}

using namespace std;

long long A = 0;
vector<SEQ_1> C;
void readInput(InStream& stream){
    A = stream.readLong();
    while(C.size() < A){
        SEQ_1 seq_1_elem;
        while(seq_1_elem.B.size() < A){
            SEQ_2 seq_2_elem;
            seq_2_elem.A = stream.readLong();
            assert(seq_2_elem.A == seq_1_elem.B.size());
            seq_1_elem.B.push_back(seq_2_elem);
        }
        C.push_back(seq_1_elem);
    }
    inf.readInt(1, 100);
    inf.readEoln();
    inf.readEof();
}

int main()
{
    registerValidation();
    inf.strict = false;
    readInput();
    return 0;
}

END
;
1;