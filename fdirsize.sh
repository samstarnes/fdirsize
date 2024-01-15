#!/bin/zsh
# FDirSize.sh
# Can't do $(whoami) or $HOME since mounting requires root and $(whoami) will return root
# unless you read through this... https://rhodesmill.org/brandon/2010/mounting-windows-shares-in-linux-userspace/
# Change your username below
HOME="/home/phoenix"
if [ -d "$HOME/mnt/FDirSize" ]
then
  echo "Directory $HOME/mnt/FDirSize exists."
else
  mkdir -p $HOME/mnt/FDirSize
fi
mdir=$1
bn="${1##*/}"
mfds="mnt/FDirSize"
lgf="$HOME/$mfds/$bn.files-directory.log"
pnt="$HOME/$mfds/$bn.FDirSize.F.log"
du -abcx $1 --exclude /proc --exclude /sys --exclude /dev --exclude /mnt | sort -nr > $HOME/$mfds/$bn.files-directory.log
awk '{sum=0} {sum=sum+$1} {printf $1" ""%s ",$0" \n"}' $HOME/$mfds/$bn.files-directory.log | sed -e 's/^[ \t]*//' | numfmt --to=iec-i | awk '{printf "%s "$2" ",$1} {$1=$2="";print "\""$0"\""}' | tr -s ' ' | sed 's/\" total\"/\"total\"/g' | sed 's/\" \/home/\"\/home/g' | sed 's/\ \"\ /\ \"/g' > $pnt
echo "Sent the final log to:"
echo "$pnt"
