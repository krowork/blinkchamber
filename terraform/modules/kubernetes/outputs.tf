# Este fichero está intencionadamente vacío por ahora.
# Se rellenará con los outputs del clúster de Kubernetes más adelante.
output "pet_name" {
  description = "The name of the pet."
  value       = random_pet.this.id
}
