# Este fichero está intencionadamente vacío por ahora.
# Se rellenará con los outputs de la base de datos más adelante.
output "pet_name" {
  description = "The name of the pet."
  value       = random_pet.this.id
}
