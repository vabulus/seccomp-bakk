mkdir -p /Chestnut/Binalyzer/cached_results/
sed -i 's/from cfg import cached_results_folder/cached_results_folder = "cached_results"/' /Chestnut/Binalyzer/syscalls.py
cd /Chestnut/Binalyzer
python3 /Chestnut/Binalyzer/syscalls.py /usr/bin/redis-server
python3 /Chestnut/Binalyzer/policy.py /usr/bin/redis-server
cp /Chestnut/Binalyzer/cached_results/policy__usr_bin_redis-server.json /Chestnut/ChestnutPatcher/
cd /Chestnut/ChestnutPatcher && make
/Chestnut/ChestnutPatcher/rewrite.sh /usr/bin/redis-server
