# Este fichero está intencionadamente vacío por ahora.
# Se rellenará con los outputs de red más adelante.
output "pet_name" {
  description = "The name of the pet."
  value       = random_pet.this.id
}
