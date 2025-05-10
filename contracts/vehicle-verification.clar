;; Vehicle Verification Contract
;; This contract validates self-driving vehicles and stores their registration information

(define-data-var admin principal tx-sender)

;; Vehicle registration status
(define-map vehicles
  { vehicle-id: (string-utf8 36) }
  {
    owner: principal,
    make: (string-utf8 50),
    model: (string-utf8 50),
    year: uint,
    vin: (string-utf8 17),
    autonomous-level: uint,
    is-verified: bool,
    registration-time: uint
  }
)

;; Verification authorities
(define-map verification-authorities
  { authority-id: principal }
  { is-active: bool }
)

;; Error codes
(define-constant ERR_UNAUTHORIZED u1)
(define-constant ERR_ALREADY_REGISTERED u2)
(define-constant ERR_NOT_FOUND u3)
(define-constant ERR_INVALID_DATA u4)

;; Add a verification authority
(define-public (add-verification-authority (authority-id principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (map-set verification-authorities { authority-id: authority-id } { is-active: true })
    (ok true)
  )
)

;; Remove a verification authority
(define-public (remove-verification-authority (authority-id principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (map-delete verification-authorities { authority-id: authority-id })
    (ok true)
  )
)

;; Register a vehicle
(define-public (register-vehicle
    (vehicle-id (string-utf8 36))
    (make (string-utf8 50))
    (model (string-utf8 50))
    (year uint)
    (vin (string-utf8 17))
    (autonomous-level uint))
  (let
    ((vehicle-data (map-get? vehicles { vehicle-id: vehicle-id })))
    (asserts! (is-none vehicle-data) (err ERR_ALREADY_REGISTERED))
    (asserts! (and (> (len vin) u0) (<= autonomous-level u5)) (err ERR_INVALID_DATA))

    (map-set vehicles
      { vehicle-id: vehicle-id }
      {
        owner: tx-sender,
        make: make,
        model: model,
        year: year,
        vin: vin,
        autonomous-level: autonomous-level,
        is-verified: false,
        registration-time: block-height
      }
    )
    (ok true)
  )
)

;; Verify a vehicle
(define-public (verify-vehicle (vehicle-id (string-utf8 36)))
  (let
    ((authority (map-get? verification-authorities { authority-id: tx-sender }))
     (vehicle-data (map-get? vehicles { vehicle-id: vehicle-id })))

    (asserts! (and (is-some authority) (get is-active (unwrap! authority (err ERR_UNAUTHORIZED)))) (err ERR_UNAUTHORIZED))
    (asserts! (is-some vehicle-data) (err ERR_NOT_FOUND))

    (map-set vehicles
      { vehicle-id: vehicle-id }
      (merge (unwrap! vehicle-data (err ERR_NOT_FOUND)) { is-verified: true })
    )
    (ok true)
  )
)

;; Get vehicle information
(define-read-only (get-vehicle-info (vehicle-id (string-utf8 36)))
  (map-get? vehicles { vehicle-id: vehicle-id })
)

;; Check if vehicle is verified
(define-read-only (is-vehicle-verified (vehicle-id (string-utf8 36)))
  (match (map-get? vehicles { vehicle-id: vehicle-id })
    vehicle-data (ok (get is-verified vehicle-data))
    (err ERR_NOT_FOUND)
  )
)

;; Transfer vehicle ownership
(define-public (transfer-vehicle (vehicle-id (string-utf8 36)) (new-owner principal))
  (let
    ((vehicle-data (map-get? vehicles { vehicle-id: vehicle-id })))

    (asserts! (is-some vehicle-data) (err ERR_NOT_FOUND))
    (asserts! (is-eq (get owner (unwrap! vehicle-data (err ERR_NOT_FOUND))) tx-sender) (err ERR_UNAUTHORIZED))

    (map-set vehicles
      { vehicle-id: vehicle-id }
      (merge (unwrap! vehicle-data (err ERR_NOT_FOUND)) { owner: new-owner })
    )
    (ok true)
  )
)
