cd /Chestnut/Binalyzer
time python3 /Chestnut/Binalyzer/filter.py /app/custom_app
cp /Chestnut/Binalyzer/cached_results/policy__app_custom_app.json /Chestnut/ChestnutPatcher/
cd /Chestnut/ChestnutPatcher && make
/Chestnut/ChestnutPatcher/rewrite.sh /app/custom_app
