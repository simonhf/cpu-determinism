#!/bin/bash

# export USE_ITERATIONS="100" USE_SCALING_FREQ="scaling_min_freq" ; ./test-cpu-determinism.sh
# export USE_ITERATIONS="100" USE_SCALING_FREQ="scaling_max_freq" ; ./test-cpu-determinism.sh

echo "# validating sudo powers"
sudo --validate

echo "# checking prereqs"
gcc        -v       > /dev/null 2>&1 || { echo >&2 "ERROR: require gcc"       " but it's not installed. Aborting."; exit 1; }
perl       -v       > /dev/null 2>&1 || { echo >&2 "ERROR: require perl"      " but it's not installed. Aborting."; exit 1; }
cpupower   -v       > /dev/null 2>&1 || { echo >&2 "ERROR: require cpupower"  " but it's not installed. Aborting."; exit 1; }
top        -v       > /dev/null 2>&1 || { echo >&2 "ERROR: require top"       " but it's not installed. Aborting."; exit 1; }
schedtool  -v       > /dev/null 2>&1 || { echo >&2 "ERROR: require schedtool" " but it's not installed. Aborting. Consider running: sudo apt install schedtool"; exit 1; }
egrep     --version > /dev/null 2>&1 || { echo >&2 "ERROR: require egrep"     " but it's not installed. Aborting."; exit 1; }
pr        --version > /dev/null 2>&1 || { echo >&2 "ERROR: require pr"        " but it's not installed. Aborting."; exit 1; }
pstree    --version > /dev/null 2>&1 || { echo >&2 "ERROR: require pstree"    " but it's not installed. Aborting."; exit 1; }
stdbuf    --version > /dev/null 2>&1 || { echo >&2 "ERROR: require stdbuf"    " but it's not installed. Aborting."; exit 1; }
#gdb       --version > /dev/null 2>&1 || { echo >&2 "ERROR: require gdb"       " but it's not installed. Aborting. Consider running: sudo apt install gdb"      ; exit 1; }

if [[ -z "${USE_SCALING_FREQ}" ]]; then
  USE_SCALING_FREQ="scaling_max_freq"
fi

echo "# creating unique log directory"
export USE_DATE=$(date +"%Y%m%d-%H%M%S") # e.g. 20240213-111754
export USE_OS=$(perl -e '$_ = `lsb_release -a 2>&1 | egrep "^Description:"`; chomp; s~Description:\s*~~; s~\s+~-~g; printf qq[%s], $_;') # e.g. Ubuntu-22.04.1-LTS
export USE_CPU=$(perl -e '$_ = `lscpu 2>&1 | egrep "^Model name:"`; chomp; s~Model name:\s*~~; s~\s+~-~g; s~\(R\)~~gi; s~\@\-~~g; printf qq[%s], $_;') # e.g. AMD Ryzen 9 3950X 16-Core Processor
export USE_ARCH=$(perl -e '$_ = `lscpu 2>&1 | egrep "^Architecture:"`; chomp; s~Architecture:\s*~~; s~\s+~-~g; printf qq[%s], $_;') # e.g. x86_64
export USE_CPUS=x$(perl -e '$_ = `lscpu 2>&1 | egrep "^CPU.s.:"`; chomp; s~CPU.s.:\s*~~; s~\s+~-~g; printf qq[%s], $_;') # e.g. 32
export USE_DIR=logs-$USE_OS-$USE_ARCH-$USE_CPUS-$USE_CPU-$USE_DATE-$USE_SCALING_FREQ
mkdir --verbose $USE_DIR

(
echo "# entering inner bash"
(

export USE_CPUID=$((`nproc`/2))
echo "# export USE_CPUID=$USE_CPUID"

echo "# gcc --version"
gcc --version | egrep gcc

echo "# compiling executables"
gcc -DUSE_CLOCKGETTIME -g -O2 -S -o $USE_DIR/test-cpu-determinism.clogt.s test-cpu-determinism.c && gcc -o $USE_DIR/test-cpu-determinism.clogt.exe $USE_DIR/test-cpu-determinism.clogt.s || exit 1
gcc -DUSE_GETTIMEOFDAY -g -O2 -S -o $USE_DIR/test-cpu-determinism.gtofd.s test-cpu-determinism.c && gcc -o $USE_DIR/test-cpu-determinism.gtofd.exe $USE_DIR/test-cpu-determinism.gtofd.s || exit 1
gcc -DUSE_RDTSC        -g -O2 -S -o $USE_DIR/test-cpu-determinism.rdtsc.s test-cpu-determinism.c && gcc -o $USE_DIR/test-cpu-determinism.rdtsc.exe $USE_DIR/test-cpu-determinism.rdtsc.s || exit 1
gcc -DUSE_WITHOUTCLOCK -g -O2 -S -o $USE_DIR/test-cpu-determinism.woclo.s test-cpu-determinism.c && gcc -o $USE_DIR/test-cpu-determinism.woclo.exe $USE_DIR/test-cpu-determinism.woclo.s || exit 1

gdb --version > /dev/null 2>&1 && {
# come here and run gdb only if it is installed
gdb -q --batch -ex 'disas burn_cpu' $USE_DIR/test-cpu-determinism.clogt.exe > $USE_DIR/test-cpu-determinism.clogt.exe.burn_cpu.disas
gdb -q --batch -ex 'disas burn_cpu' $USE_DIR/test-cpu-determinism.gtofd.exe > $USE_DIR/test-cpu-determinism.gtofd.exe.burn_cpu.disas
gdb -q --batch -ex 'disas burn_cpu' $USE_DIR/test-cpu-determinism.rdtsc.exe > $USE_DIR/test-cpu-determinism.rdtsc.exe.burn_cpu.disas
gdb -q --batch -ex 'disas burn_cpu' $USE_DIR/test-cpu-determinism.woclo.exe > $USE_DIR/test-cpu-determinism.woclo.exe.burn_cpu.disas
}

# note: disable tracker3 via https://stackoverflow.com/questions/72827703/how-to-disable-file-indexing-in-ubuntu-22-04-tracker3
# sudo apt-mark hold tracker
# sudo apt-mark hold tracker-extract
# sudo apt-mark hold tracker-miner-fs
# sudo chmod -x /usr/libexec/tracker-extract-3
# sudo chmod -x /usr/libexec/tracker-miner-fs-3
# tracker3 reset --filesystem --rss # Clean all database
# tracker3 daemon --terminate

echo "# disabling cpufreq boost, setting cpufreq CPU$USE_CPUID governor to performance, and setting cpufreq CPU$USE_CPUID scaling frequency; see https://docs.kernel.org/admin-guide/pm/cpufreq.html"

if [ -f "/sys/devices/system/cpu/cpufreq/boost" ]
then

echo "# cat /sys/devices/system/cpu/cpufreq/boost"
cat /sys/devices/system/cpu/cpufreq/boost

echo "# set /sys/devices/system/cpu/cpufreq/boost to 0"
echo 0 | sudo tee /sys/devices/system/cpu/cpufreq/boost

echo "# cat /sys/devices/system/cpu/cpufreq/boost"
cat /sys/devices/system/cpu/cpufreq/boost

else

echo "# /sys/devices/system/cpu/cpufreq/boost does not exist"

fi

echo "# sudo cpupower --cpu $USE_CPUID frequency-info"
sudo cpupower --cpu $USE_CPUID frequency-info

echo "# cat /sys/devices/system/cpu/cpu$USE_CPUID/cpufreq/scaling_available_governors"
cat /sys/devices/system/cpu/cpu$USE_CPUID/cpufreq/scaling_available_governors

echo "# cat /sys/devices/system/cpu/cpu$USE_CPUID/cpufreq/scaling_governor"
cat /sys/devices/system/cpu/cpu$USE_CPUID/cpufreq/scaling_governor

echo "# set /sys/devices/system/cpu/cpu$USE_CPUID/cpufreq/scaling_governor to performance"
echo performance | sudo tee /sys/devices/system/cpu/cpu$USE_CPUID/cpufreq/scaling_governor

echo "# cat /sys/devices/system/cpu/cpu$USE_CPUID/cpufreq/scaling_governor"
cat /sys/devices/system/cpu/cpu$USE_CPUID/cpufreq/scaling_governor

echo "# cat /sys/devices/system/cpu/cpu$USE_CPUID/cpufreq/scaling_{cur,min,max}_freq"
cat /sys/devices/system/cpu/cpu$USE_CPUID/cpufreq/scaling_cur_freq | tee $USE_DIR/scaling_cur_freq
cat /sys/devices/system/cpu/cpu$USE_CPUID/cpufreq/scaling_min_freq | tee $USE_DIR/scaling_min_freq
cat /sys/devices/system/cpu/cpu$USE_CPUID/cpufreq/scaling_max_freq | tee $USE_DIR/scaling_max_freq

# works on AMD but fails on Intel: echo "# set /sys/devices/system/cpu/cpu$USE_CPUID/cpufreq/scaling_{min,max}_freq to USE_SCALING_FREQ=$USE_SCALING_FREQ"
# works on AMD but fails on Intel: # "NOTE: when setting a policy you need to first set scaling_max_freq, then scaling_min_freq." see https://www.kernel.org/doc/Documentation/cpu-freq/user-guide.txt
# works on AMD but fails on Intel: cat $USE_DIR/$USE_SCALING_FREQ | sudo tee /sys/devices/system/cpu/cpu$USE_CPUID/cpufreq/scaling_max_freq
# works on AMD but fails on Intel: cat $USE_DIR/$USE_SCALING_FREQ | sudo tee /sys/devices/system/cpu/cpu$USE_CPUID/cpufreq/scaling_min_freq

echo "# set max scaling frequencies: sudo cpupower frequency-set --max `cat $USE_DIR/$USE_SCALING_FREQ`"
sudo cpupower frequency-set --max `cat $USE_DIR/$USE_SCALING_FREQ` > /dev/null
echo "# set min scaling frequencies: sudo cpupower frequency-set --min `cat $USE_DIR/$USE_SCALING_FREQ`"
sudo cpupower frequency-set --min `cat $USE_DIR/$USE_SCALING_FREQ` > /dev/null

echo "# echo waiting for cpufreq change dust to settle"
sleep 1

echo "# cat /sys/devices/system/cpu/cpu$USE_CPUID/cpufreq/scaling_{cur,min,max}_freq"
cat /sys/devices/system/cpu/cpu$USE_CPUID/cpufreq/scaling_{cur,min,max}_freq

echo "# sudo cpupower --cpu $USE_CPUID frequency-info"
sudo cpupower --cpu $USE_CPUID frequency-info

echo "# sudo ntpdate -b pool.ntp.org"
#update takes too long: sudo ntpdate -b pool.ntp.org > /dev/null 2>&1
perl -e 'use Time::HiRes; while(1){ $out = `ntpdate -q pool.ntp.org 2>&1 | egrep adjust`; $t_old = $t; do{ $t = Time::HiRes::time(); sleep(0.001); }while(int($t) < (2 + int($t_old))); printf qq[%f %s], $t, $out; }' > $USE_DIR/ntp.log &

# mkdir --parents ./.config/procps/
# # manually configure top
# cp ~/.config/procps/toprc ./.config/procps/.

# show all CPU temperatures and current CPU frequency
perl -e 'while(1){ $res = `cat $temp_cur_freq`; chomp $res; $res =~ s~[\r\n]+~ ~gs; printf qq[%f %s %s\r\n], Time::HiRes::time(), $res; sleep 1; } sub BEGIN{ use Time::HiRes; $|++; $temp_cur_freq = sprintf qq[/sys/devices/virtual/thermal/thermal_zone*/temp /sys/devices/system/cpu/cpu%s/cpufreq/scaling_cur_freq], $ENV{USE_CPUID}; }' > $USE_DIR/temp-and-freq.log &

# on stdout show all threads using CPU on $USE_CPUID
# on stderr show all user and system CPU from all CPUs
# note: how to use own config for top: https://askubuntu.com/questions/1460240/why-sum-of-all-process-cpu-is-greater-than-total-cpu-utilisation-in-top-co/
# e.g. %Cpu16 :  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
# e.g.  P  %CPU     PID USER      PR  NI    VIRT    RES    SHR S  %MEM     TIME+ COMMAND
# e.g. 16   0.0      67 root       0 -20       0      0      0 I   0.0   0:00.00 [kworker/16:0H-events_highpri]
HOME=`pwd` top -H -d 1 -b -c -w512 1 | egrep --line-buffered "(^\s*$USE_CPUID\s+|[ ]COMMAND|Cpu[0-9])" | perl -lane 'if(m~Cpu(\d+)\s*:\s*([\d\.]+) us,\s*([\d\.]+) sy,\s*([\d\.]+) ni,~){ ($cpuid, $us, $sy, $ni) = ($1, $2, $3, $4); $us_sy .= sprintf qq[%5.1f,%5.1f,%5.1f;], $us, $sy, $ni; if((defined $last_cpuid) && ($cpuid < $last_cpuid)){ printf stderr qq[%f (us,sy,ni;)[]%s\n], Time::HiRes::time(), $us_sy; undef $us_sy; } $last_cpuid = $cpuid; next; } if(m~^\s*(\d+)\s+([\d\.]+)~){ ($cpuid, $cpupc) = ($1, $2); next if($cpupc eq q[0.0]); s~ logs-[^/]+/~ ~; } if(m~COMMAND~){ if($n <= 0){ $n = 50; }else{ next; } } printf qq[%f %s\n], Time::HiRes::time(), $_; $n --; sub BEGIN{ use Time::HiRes; $|++; }' 2> $USE_DIR/top.stderr.log > $USE_DIR/top.stdout.log &

perl -e 'while(1){ `sudo --validate`; sleep 10; }' & # keep validating to keep sudo alive for any length test

# use schedtool to set niceness and process affinity at the same time
# https://stackoverflow.com/questions/11614294/how-can-i-set-niceness-and-process-affinity-at-the-same-time

sudo --preserve-env time schedtool -a $USE_CPUID -n -20 -e stdbuf --output=L $USE_DIR/test-cpu-determinism.clogt.exe 2> $USE_DIR/test-cpu-determinism.clogt.1.stderr.log > >(tee $USE_DIR/test-cpu-determinism.clogt.1.stdout.log)
sudo --preserve-env time schedtool -a $USE_CPUID -n -20 -e stdbuf --output=L $USE_DIR/test-cpu-determinism.gtofd.exe 2> $USE_DIR/test-cpu-determinism.gtofd.1.stderr.log > >(tee $USE_DIR/test-cpu-determinism.gtofd.1.stdout.log)
sudo --preserve-env time schedtool -a $USE_CPUID -n -20 -e stdbuf --output=L $USE_DIR/test-cpu-determinism.rdtsc.exe 2> $USE_DIR/test-cpu-determinism.rdtsc.1.stderr.log > >(tee $USE_DIR/test-cpu-determinism.rdtsc.1.stdout.log)
sudo --preserve-env time schedtool -a $USE_CPUID -n -20 -e stdbuf --output=L $USE_DIR/test-cpu-determinism.woclo.exe 2> $USE_DIR/test-cpu-determinism.woclo.1.stderr.log > >(tee $USE_DIR/test-cpu-determinism.woclo.1.stdout.log)

echo "# start $NPROC lower priority chew_cpu_forever processes to simulate 100% CPU load"
export NPROC=`nproc` ; for i in `seq 1 $NPROC` ; do (nice -n 19 perl -e 'while(1){} if(0){chew_cpu_forever}' &) ; done

sudo --preserve-env time schedtool -a $USE_CPUID -n -20 -e stdbuf --output=L $USE_DIR/test-cpu-determinism.clogt.exe 2> $USE_DIR/test-cpu-determinism.clogt.2.stderr.log > >(tee $USE_DIR/test-cpu-determinism.clogt.2.stdout.log)
sudo --preserve-env time schedtool -a $USE_CPUID -n -20 -e stdbuf --output=L $USE_DIR/test-cpu-determinism.gtofd.exe 2> $USE_DIR/test-cpu-determinism.gtofd.2.stderr.log > >(tee $USE_DIR/test-cpu-determinism.gtofd.2.stdout.log)
sudo --preserve-env time schedtool -a $USE_CPUID -n -20 -e stdbuf --output=L $USE_DIR/test-cpu-determinism.rdtsc.exe 2> $USE_DIR/test-cpu-determinism.rdtsc.2.stderr.log > >(tee $USE_DIR/test-cpu-determinism.rdtsc.2.stdout.log)
sudo --preserve-env time schedtool -a $USE_CPUID -n -20 -e stdbuf --output=L $USE_DIR/test-cpu-determinism.woclo.exe 2> $USE_DIR/test-cpu-determinism.woclo.2.stderr.log > >(tee $USE_DIR/test-cpu-determinism.woclo.2.stdout.log)

# works on AMD but fails on Intel: echo "# restore /sys/devices/system/cpu/cpu$USE_CPUID/cpufreq/scaling_{min,max}_freq"
# works on AMD but fails on Intel: # "NOTE: when setting a policy you need to first set scaling_max_freq, then scaling_min_freq." see https://www.kernel.org/doc/Documentation/cpu-freq/user-guide.txt
# works on AMD but fails on Intel: cat $USE_DIR/scaling_max_freq | sudo tee /sys/devices/system/cpu/cpu$USE_CPUID/cpufreq/scaling_max_freq
# works on AMD but fails on Intel: cat $USE_DIR/scaling_min_freq | sudo tee /sys/devices/system/cpu/cpu$USE_CPUID/cpufreq/scaling_min_freq

echo "# restore max scaling frequencies: sudo cpupower frequency-set --max `cat $USE_DIR/scaling_max_freq`"
sudo cpupower frequency-set --max `cat $USE_DIR/scaling_max_freq` > /dev/null
echo "# restore min scaling frequencies: sudo cpupower frequency-set --min `cat $USE_DIR/scaling_min_freq`"
sudo cpupower frequency-set --min `cat $USE_DIR/scaling_min_freq` > /dev/null

echo "# echo waiting for cpufreq change dust to settle"
sleep 1

echo "# cat /sys/devices/system/cpu/cpu$USE_CPUID/cpufreq/scaling_{cur,min,max}_freq"
cat /sys/devices/system/cpu/cpu$USE_CPUID/cpufreq/scaling_{cur,min,max}_freq

echo "# sudo cpupower --cpu $USE_CPUID frequency-info"
sudo cpupower --cpu $USE_CPUID frequency-info

echo "# kill all chew_cpu_forever process"
pkill --full chew_cpu_forever

echo "# pstree -A -p $$ # sub processes from this bash script BEFORE killing"
pstree -A -p $$

echo "# kill sub-processes of $BASHPID excluding $BASHPID and the kill generation command"
perl -e '$_ = `pstree -A -p $ARGV[0]`; while(m~([a-z][^\(]*)\((\d+)~gis){ ($name, $pid) = ($1, $2); $kill = sprintf qq[sh -c "kill -KILL $pid 2>&1 # $name"]; if(($pid eq $ARGV[0]) || ($pid eq $$)){ $kill = q[#] . $kill; } printf qq[%s\n], $kill; `$kill`; }' $BASHPID

echo "# pstree -A -p $$ # sub processes from this bash script AFTER killing"
pstree -A -p $$

echo "# show burn_cpu() functions; clogt, gtofd, rdtsc, & woclo"
perl -e '$lines = `cat \$USE_DIR/test-cpu-determinism.clogt.s`; ($burn) = $lines =~ m~(burn_cpu:.*?\.cfi_endproc)~s; printf qq[%s\n], $burn;' | egrep -v "(.cfi_|endbr64|.p2align|.loc|.L[BFV])" > $USE_DIR/test-cpu-determinism.clogt.burn.s
perl -e '$lines = `cat \$USE_DIR/test-cpu-determinism.gtofd.s`; ($burn) = $lines =~ m~(burn_cpu:.*?\.cfi_endproc)~s; printf qq[%s\n], $burn;' | egrep -v "(.cfi_|endbr64|.p2align|.loc|.L[BFV])" > $USE_DIR/test-cpu-determinism.gtofd.burn.s
perl -e '$lines = `cat \$USE_DIR/test-cpu-determinism.rdtsc.s`; ($burn) = $lines =~ m~(burn_cpu:.*?\.cfi_endproc)~s; printf qq[%s\n], $burn;' | egrep -v "(.cfi_|endbr64|.p2align|.loc|.L[BFV])" > $USE_DIR/test-cpu-determinism.rdtsc.burn.s
perl -e '$lines = `cat \$USE_DIR/test-cpu-determinism.woclo.s`; ($burn) = $lines =~ m~(burn_cpu:.*?\.cfi_endproc)~s; printf qq[%s\n], $burn;' | egrep -v "(.cfi_|endbr64|.p2align|.loc|.L[BFV])" > $USE_DIR/test-cpu-determinism.woclo.burn.s
pr --width 192 --omit-pagination --merge --expand-tabs $USE_DIR/test-cpu-determinism.clogt.burn.s $USE_DIR/test-cpu-determinism.gtofd.burn.s $USE_DIR/test-cpu-determinism.rdtsc.burn.s $USE_DIR/test-cpu-determinism.woclo.burn.s

echo "# echo todo: try on intel"

echo "# find logs in directory: $USE_DIR/"

)
) 2>&1 | tee $USE_DIR/test-cpu-determinism.log

