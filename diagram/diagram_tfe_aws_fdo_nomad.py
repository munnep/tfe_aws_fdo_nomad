from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import EC2, EC2AutoScaling
from diagrams.aws.network import Route53,VPC, PrivateSubnet, PublicSubnet, InternetGateway, NATGateway, ElbApplicationLoadBalancer
from diagrams.onprem.compute import Server
from diagrams.aws.storage import SimpleStorageServiceS3Bucket
from diagrams.aws.database import RDSPostgresqlInstance
from diagrams.aws.database import ElasticacheForRedis
from diagrams.custom import Custom

# Variables
title = "VPC with 1 public subnet for the Nomad Server and Nomad client \n and 1 private subnet for PostgreSQL and Redis"
outformat = "png"
filename = "diagram_tfe_aws_fdo_nomad"
direction = "TB"


with Diagram(
    name=title,
    direction=direction,
    filename=filename,
    outformat=outformat,
) as diag:
    # Non Clustered
    user = Server("user")
    route53=Route53("DNS record in AWS")

    # Cluster 
    with Cluster("vpc"):
        bucket_tfe = SimpleStorageServiceS3Bucket("TFE bucket")
        igw_gateway = InternetGateway("igw")

        with Cluster("Availability Zone: eu-north-1b"):

            # Subcluster
            with Cluster("subnet_private2"):
                with Cluster("DB subnet"):
                            postgresql2 = RDSPostgresqlInstance("RDS different AZ")
                # with Cluster("Redis subnet"):
                #         redis2 = ElasticacheForRedis("Redis different AZ")                

        with Cluster("Availability Zone: eu-north-1a"):
            # Subcluster 
            with Cluster("subnet_public1"):
                nomad_server = Custom("Nomad server", "./images/nomad.png")
                nomad_client = Custom("Nomad client \n running TFE instance", "./images/nomad.png")
                nat_gateway = NATGateway("nat_gateway")
            # Subcluster
            with Cluster("subnet_private1"):
                with Cluster("DB subnet"):
                        postgresql = RDSPostgresqlInstance("RDS Instance")
                with Cluster("Redis subnet"):
                        redis = ElasticacheForRedis("Redis Instance")        
 
    # Diagram
    user >>  route53
    user >>  nomad_server >> nomad_client
    user >>  nomad_client >> [redis,
                       postgresql,
                       bucket_tfe
    ]
    
diag
