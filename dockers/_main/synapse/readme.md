6. Create an Admin User

Once running:

sudo docker exec -it synapse_server register_new_matrix_user  http://localhost:8008 -c /data/homeserver.yaml
<!-- sudo docker exec -it synapse_server register_new_matrix_user   http://localhost:8008 -c /data/homeserver.yaml   -u hero -p hero --admin -->



<!-- to migrate from rocket chat to synapse follow migration/Worteks -->


<!-- the below script will need to ruun on host and  create a token pase it to /data/rc2matrix.yaml in hs_token and as_token -->
python /migration/Worteks/RC2Matrix/rc2matrix.py -v -n localhost:8008 -u hero -p hero

python /migration/Worteks/RC2Matrix/rc2matrix.py  -v -n localhost:8008 -t syt_aGVybw_DNrXgVQBhVdRPPEOoAAQ_2GFiM2 -a syt_aGVybw_DNrXgVQBhVdRPPEOoAAQ_2GFiM2 -i data/