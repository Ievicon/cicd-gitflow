# --- SSH key pair ----------------------------------------------------------
# Generates a fresh key pair for the servers and saves the PRIVATE key locally.
# You will paste this private key into GitHub as the SSH_KEY secret.
resource "tls_private_key" "this" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "this" {
  key_name   = "${var.project}-key"
  public_key = tls_private_key.this.public_key_openssh
}

# Write the private key to a local file (chmod 600) for use by the pipeline / ssh.
resource "local_file" "private_key" {
  content         = tls_private_key.this.private_key_openssh
  filename        = "${path.module}/${var.project}-key.pem"
  file_permission = "0600"
}
