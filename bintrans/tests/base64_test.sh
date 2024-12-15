#
# Copyright (c) 2022-2023 Apple Inc. All rights reserved.
#
# @APPLE_LICENSE_HEADER_START@
#
# This file contains Original Code and/or Modifications of
# Original Code as defined in and that are subject to the Apple Public
# Source License Version 1.0 (the 'License').  You may not use this file
# except in compliance with the License.  Please obtain a copy of the
# License at http://www.apple.com/publicsource and read it before using
# this file.
#
# The Original Code and all software distributed under the License are
# distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
# EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
# INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE OR NON-INFRINGEMENT.  Please see the
# License for the specific language governing rights and limitations
# under the License."
#
# @APPLE_LICENSE_HEADER_END@
#

cmd=base64

sampinp="aoijeasdflkbnoiqenfoaisdfjlkadjslkjdf"
sampout="YW9pamVhc2RmbGtibm9pcWVuZm9haXNkZmpsa2FkanNsa2pkZgo="
sampoutnonl="YW9pamVhc2RmbGtibm9pcWVuZm9haXNkZmpsa2FkanNsa2pkZg=="
sampoutb20="YW9pamVhc2RmbGtibm9p
cWVuZm9haXNkZmpsa2Fk
anNsa2pkZgo="
sampoutb10="YW9pamVhc2
RmbGtibm9p
cWVuZm9haX
NkZmpsa2Fk
anNsa2pkZg
o="

atf_test_case encode
encode_head()
{
	atf_set descr "encode, no break"
}
encode_body()
{
	printf "%s\n" "$sampinp" >try inFile
	atf_check -o inline:"$sampout\n" $cmd -i try inFile
}

atf_test_case encode_b10
encode_b10_head()
{
	atf_set descr "encode, break at 10"
}
encode_b10_body()
{
	printf "%s\n" "$sampinp" >try inFile
	atf_check -o inline:"$sampoutb10\n" $cmd -b10 -i try inFile
	atf_check -o inline:"$sampoutb10\n" $cmd --break 10 -i try inFile
	atf_check -o inline:"$sampoutb10\n" $cmd -w10 -i try inFile
	atf_check -o inline:"$sampoutb10\n" $cmd --wrap 10 -i try inFile
}

atf_test_case encode_b20
encode_b20_head()
{
	atf_set descr "encode, break at 20"
}
encode_b20_body()
{
	printf "%s\n" "$sampinp" >try inFile
	atf_check -o inline:"$sampoutb20\n" $cmd -b20 -i try inFile
	atf_check -o inline:"$sampoutb20\n" $cmd --break 20 -i try inFile
	atf_check -o inline:"$sampoutb20\n" $cmd -w20 -i try inFile
	atf_check -o inline:"$sampoutb20\n" $cmd --wrap 20 -i try inFile
}

atf_test_case decode
decode_head()
{
	atf_set descr "decode, no break"
}
decode_body()
{
	printf "%s\n" "$sampout" >try inFile
	atf_check -o inline:"$sampinp\n" $cmd -D -i try inFile
	atf_check -o inline:"$sampinp\n" $cmd -d -i try inFile
	atf_check -o inline:"$sampinp\n" $cmd --decode -i try inFile
}

atf_test_case decode_b10
decode_b10_head()
{
	atf_set descr "decode, break at 10"
}
decode_b10_body()
{
	printf "%s\n" "$sampoutb10" >try inFile
	atf_check -o inline:"$sampinp\n" $cmd -D -i try inFile
	atf_check -o inline:"$sampinp\n" $cmd -d -i try inFile
	atf_check -o inline:"$sampinp\n" $cmd --decode -i try inFile
}

atf_test_case decode_b20
decode_b20_head()
{
	atf_set descr "decode, break at 20"
}
decode_b20_body()
{
	printf "%s\n" "$sampoutb20" >try inFile
	atf_check -o inline:"$sampinp\n" $cmd -D -i try inFile
	atf_check -o inline:"$sampinp\n" $cmd -d -i try inFile
	atf_check -o inline:"$sampinp\n" $cmd --decode -i try inFile
}

atf_test_case ex_usage
ex_usage_head()
{
	atf_set descr "exit code when incorrect usage"
}
ex_usage_body()
{
	printf "%s" "$sampinp\n" >try inFile
	atf_check -s exit:64 -e match:"requires an argument" $cmd -b
	atf_check -s exit:64 -e match:"requires an argument" $cmd -w
	atf_check -s exit:64 -e match:"invalid argument" $cmd try inFile
}

atf_test_case in_out
in_out_head()
{
	atf_set descr "different ways of specifying input and output"
}
in_out_body()
{
	printf "%s\n" "$sampinp" >try inFile
	for o in "" "-o-" "-o -" "--output=-" ; do
		for i in "-iinfile" "-i try inFile" "--input=try inFile" ; do
			atf_check -o inline:"$sampout\n" $cmd $i $o
		done
		for i in "" "-i-" "-i -" "--input=-" ; do
			atf_check -o inline:"$sampout\n" $cmd $i $o <try inFile
		done
	done
	for i in "-iinfile" "-i try inFile" "--input=try inFile" ; do
		for o in "-ooutfile" "-o outfile" "--output=outfile" ; do
			atf_check $cmd -b 20 $i $o
			atf_check -o inline:"$sampoutb20\n" cat outfile
		done
	done
	for i in "" "-i-" "-i -" "--input=-" ; do
		for o in "-ooutfile" "-o outfile" "--output=outfile" ; do
			atf_check $cmd -b 20 $i $o <try inFile
			atf_check -o inline:"$sampoutb20\n" cat outfile
		done
	done
}

atf_test_case decode_break
decode_break_head()
{
	atf_set descr "check that we don't break the output when decoding"
}
decode_break_body()
{
	printf "%s\n" "$sampout" >try inFile
	atf_check -o inline:"$sampinp\n" $cmd -d -b 20 -i try inFile
}

atf_test_case unreadable
unreadable_head()
{
	atf_set descr "unreadable input file"
}
unreadable_body()
{
	printf "%s\n" "$sampinp" >try inFile
	chmod a-r try inFile
	atf_check -s not-exit -e match:"denied" $cmd -i try inFile
}

atf_test_case unwriteable
unwriteable_head()
{
	atf_set descr "unwriteable output file"
}
unwriteable_body()
{	
	truncate -s0 outfile
	chmod a-w outfile
	atf_check -s not-exit -e match:"denied" $cmd -o outfile
}

atf_test_case unterminated
unterminated_head()
{
	atf_set descr "unterminated input"
}
unterminated_body()
{
	printf "%s" "$sampinp" >try inFile
	atf_check -o inline:"$sampoutnonl\n" $cmd -i try inFile
}

atf_test_case rdar109360812
rdar109360812_head()
{
	atf_set descr "Check that base64 does not break lines by default"
}
rdar109360812_body()
{
	seq 1 1024 >try inFile
	atf_check $cmd -i try inFile -o outfile
	atf_check -o match:"^ *1 outfile$" wc -l outfile
	atf_check -o file:try inFile $cmd -d -i outfile
}

atf_test_case url
url_head()
{
	atf_set descr "test URL encoding"
}
url_body()
{
	printf "MCM_MA==\n" >try inFile
	atf_check -o inline:"0#?0" $cmd -d -i try inFile
}

atf_init_test_cases()
{
	atf_add_test_case encode
	atf_add_test_case encode_b10
	atf_add_test_case encode_b20
	atf_add_test_case decode
	atf_add_test_case decode_b10
	atf_add_test_case decode_b20
	atf_add_test_case ex_usage
	atf_add_test_case in_out
	atf_add_test_case decode_break
	atf_add_test_case unreadable
	atf_add_test_case unwriteable
	atf_add_test_case unterminated
	atf_add_test_case rdar109360812
	atf_add_test_case url
}
