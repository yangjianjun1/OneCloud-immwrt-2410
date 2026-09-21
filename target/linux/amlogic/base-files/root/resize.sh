#!/bin/bash
parted /dev/mmcblk1 resizepart 4 100%
resize2fs /dev/mmcblk1p4
echo "# Put your custom commands here that should be executed once
# the system init finished. By default this file does nothing.
exit 0">/etc/rc.local
rm -rf /root/resize.sh
