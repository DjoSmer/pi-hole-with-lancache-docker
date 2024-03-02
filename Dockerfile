FROM pihole/pihole:latest
MAINTAINER DjoSmer <djos.ghub@mail.ru>

COPY src/ /opt/

RUN bash -ex /opt/lancache/update.sh 2>&1