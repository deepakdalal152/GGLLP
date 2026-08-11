6. Create an Admin User

Once running:

sudo docker exec -it synapse_server register_new_matrix_user \  http://localhost:8008 -c /data/homeserver.yaml
<!-- sudo docker exec -it synapse_server register_new_matrix_user   http://localhost:8008 -c /data/homeserver.yaml   -u hero -p hero --admin -->

