cuj_workloads = {
  cuj1 = {
    name      = "customer-success"
    workloads = ["customer-api", "tickets-api"]
  }
  cuj2 = {
    name      = "checkout"
    workloads = ["checkout-api", "payments-api"]
  }
}