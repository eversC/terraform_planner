FROM eversc/terraform

ADD plan.sh plan.sh

RUN chmod u+x plan.sh

ENTRYPOINT ["/bin/sh", "-c", "/plan.sh"]