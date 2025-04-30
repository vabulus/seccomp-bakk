cd /Chestnut/Binalyzer
python3 /Chestnut/Binalyzer/filter.py /usr/bin/redis-server
cp /Chestnut/Binalyzer/cached_results/policy__usr_bin_redis-server.json /Chestnut/ChestnutPatcher/
cd /Chestnut/ChestnutPatcher && make
/Chestnut/ChestnutPatcher/rewrite.sh /usr/bin/redis-server
