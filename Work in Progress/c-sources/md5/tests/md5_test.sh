
for alg in $algorithms ; do
	eval "
atf_test_case self_test_${alg}
self_test_${alg}_head() {
	atf_set descr \"self-test for \$name_bsd_${alg}\"
	atf_set require.progs \"${alg}\"
}
self_test_${alg}_body() {
	atf_require_prog \"${alg}\"
	atf_check -o ignore ${alg} --self-test
}
"
	for i in $(seq $n) ; do
		eval "
atf_test_case bsd_${alg}_vec${i}
bsd_${alg}_vec${i}_head() {
	atf_set descr \"BSD mode \$name_bsd_${alg} test vector ${i}\"
	atf_set require.progs \"${alg}\"
}
bsd_${alg}_vec${i}_body() {
	atf_require_prog \"${alg}\"
	printf '%s' \"\$inp_${i}\" >in
	atf_check -o inline:\"\$out_${i}_${alg}\n\" ${alg} <in
	atf_check -o inline:\"\$name_bsd_${alg} (in) = \$out_${i}_${alg}\n\" ${alg} in
	atf_check -o inline:\"\$name_bsd_${alg} (-) = \$out_${i}_${alg}\n\" ${alg} - <in
	atf_check -o inline:\"\$out_${i}_${alg} in\n\" ${alg} -r in
	atf_check -o inline:\"\$out_${i}_${alg} -\n\" ${alg} -r - <in
	# -q overrides -r regardless of order
	for opt in -q -qr -rq ; do
		atf_check -o inline:\"\$out_${i}_${alg}\n\" ${alg} \${opt} in
	done
	atf_check -o inline:\"\$inp_${i}\$out_${i}_${alg}\n\" ${alg} -p <in
	atf_check -o inline:\"\$out_${i}_${alg}\n\" ${alg} -s \"\$inp_${i}\"
}
"

atf_test_case gnu_bflag
gnu_bflag_head()
{
	atf_set descr "Verify GNU binary mode"
	atf_set require.progs "sha256sum"
}
gnu_bflag_body()
{
	atf_require_prog "sha256sum"
	echo foo >a
	echo bar >b

	(sha256 -q a | tr -d '\n'; echo " *a") > expected
	(sha256 -q b | tr -d '\n'; echo " *b") >> expected

	atf_check -o file:expected sha256sum -b a b
	atf_check -o file:expected sha256sum --binary a b
}

atf_test_case gnu_cflag
gnu_cflag_head()
{
	atf_set descr "Verify handling of missing files in GNU check mode"
	atf_set require.progs "sha256sum"
}
gnu_cflag_body()
{
	atf_require_prog "sha256sum"

	# Verify that the *sum -c mode works even if some files are missing.
	# PR 267722 identified that we would never advance past the first record
	# to check against.  As a result, things like checking the published
	# checksums for the install media became a more manual process again if
	# you didn't download all of the images.
	for i in 2 3 4 ; do
		eval "printf '%s  inp%d\n' \"\$out_${i}_sha256\" ${i}"
	done >digests
	for combo in "2 3 4" "3 4" "2 4" "2 3" "2" "3" "4" ""; do
		rm -f inp2 inp3 inp4
		:> expected
		cnt=0
		for i in ${combo}; do
			eval "printf '%s' \"\$inp_${i}\"" > inp${i}
			printf "inp%d: OK\n" ${i} >> expected
			cnt=$((cnt + 1))
		done

		err=0
		[ "$cnt" -eq 3 ] || err=1
		atf_check -o file:expected -e ignore -s exit:${err} \
		    sha256sum -c digests
		atf_check -o file:expected -e ignore -s exit:0 \
		    sha256sum --ignore-missing -c digests
	done

}

atf_test_case gnu_cflag_mode
gnu_cflag_mode_head()
{
	atf_set descr "Verify handling of input modes in GNU check mode"
	atf_set require.progs "sha1sum"
}
gnu_cflag_mode_body()
{
	atf_require_prog "sha1sum"
	printf "The Magic Words are 01010011 01001111\r\n" >input
	# The first line is malformed per GNU coreutils but matches
	# what we produce when mode == mode_bsd && output_mode ==
	# output_reverse (i.e. `sha1 -r`) so we want to support it.
	cat >digests <<EOF
53d88300dfb2be42f0ef25e3d9de798e31bb7e69 input
53d88300dfb2be42f0ef25e3d9de798e31bb7e69 *input
53d88300dfb2be42f0ef25e3d9de798e31bb7e69  input
2290cf6ba4ac5387e520088de760b71a523871b0 ^input
c1065e0d2bbc1c67dcecee0187d61316fb9c5582 Uinput
EOF
	atf_check sha1sum --quiet --check digests
}

atf_init_test_cases()
{
	for alg in $algorithms ; do
		atf_add_test_case self_test_${alg}
		for i in $(seq $n) ; do
			atf_add_test_case bsd_${alg}_vec${i}
			atf_add_test_case gnu_${alg}_vec${i}
			atf_add_test_case perl_${alg}_vec${i}
		done
		atf_add_test_case gnu_check_${alg}
		atf_add_test_case perl_check_${alg}
	done
	atf_add_test_case gnu_bflag
	atf_add_test_case gnu_cflag
	atf_add_test_case gnu_cflag_mode
}
