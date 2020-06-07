resource "aws_db_instance" "adevinta-test" {
  allocated_storage    = 5
  storage_type         = "standard"
  engine               = "postgres"
  engine_version       = "9.6"
  instance_class       = "db.t2.micro"
  name                 = "adevintadb"
  username             = "adevinta"
  password             = "adevinta"
}

resource "aws_route53_record" "database" {
  zone_id = aws_route53_zone.postgres.id
  name = "postgresql.adevinta-test.com"
  type = "CNAME"
  ttl = "300"
  records = ["${aws_db_instance.adevinta-test.address}"]
}