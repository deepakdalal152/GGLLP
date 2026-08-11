to set password

sudo docker exec -it pihole pihole setpassword "ggllpadmin123"

Or remove password entirely (for local trusted LAN only)

sudo docker exec -it pihole pihole setpassword ""




example use of traefik


6️Create Service Folders (Example: Kitsu, Ayon, etc.)

You will create folders like /opt/ggllp-infra/kitsu/, /opt/ggllp-infra/ayon/, etc., and place the corresponding docker-compose.yml files inside them. The init.sh script will loop through each folder and bring up all services automatically.

For Ayon, for example:

/opt/ggllp-infra/ayon/docker-compose.yml
version: "3.9"

services:
  ayon:
    image: ynput/ayon:latest
    networks:
      - ${NETWORK_NAME}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.ayon.rule=Host(\`ggllp.ayon.local\`)"
      - "traefik.http.services.ayon.loadbalancer.server.port=80"

networks:
  ${NETWORK_NAME}:
    external: true
