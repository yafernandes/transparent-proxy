data "aws_route53_zone" "pipsquack" {
  name = var.domain
}

resource "aws_route53_record" "proxy" {
  zone_id = data.aws_route53_zone.pipsquack.zone_id
  name    = "${aws_instance.proxy.tags.dns_name}.tp"
  type    = "CNAME"
  ttl     = "60"
  records = [aws_instance.proxy.public_dns]
}

resource "aws_route53_record" "client" {
  zone_id = data.aws_route53_zone.pipsquack.zone_id
  name    = "${aws_instance.client.tags.dns_name}.tp"
  type    = "CNAME"
  ttl     = "60"
  records = [aws_instance.client.public_dns]
}

