FROM eversc/terraform

ADD plan.sh plan.sh

USER root
RUN chown tf plan.sh
RUN chmod u+x plan.sh
USER tf

ENTRYPOINT ["/bin/sh", "-c", "/plan.sh"]