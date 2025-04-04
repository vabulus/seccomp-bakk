#!/bin/bash

mkdir /tool/Chestnut/Binalyzer/cached_results/
sed -i 's/from cfg import cached_results_folder/cached_results_folder = "cached_results"/' /tool/Chestnut/Binalyzer/syscalls.py
cd /tool/Chestnut/Binalyzer
python3 /tool/Chestnut/Binalyzer/syscalls.py /app/vsftpd-2.3.4-infected/vsftpd
python3 /tool/Chestnut/Binalyzer/policy.py /app/vsftpd-2.3.4-infected/vsftpd
cp /tool/Chestnut/Binalyzer/cached_results/policy__app_vsftpd-2.3.4-infected_vsftpd.json /tool/Chestnut/ChestnutPatcher/
cd /tool/Chestnut/ChestnutPatcher && make
/tool/Chestnut/ChestnutPatcher/rewrite.sh /app/vsftpd-2.3.4-infected/vsftpd /app/vsftpd-2.3.4-infected/vsftpd.conf
