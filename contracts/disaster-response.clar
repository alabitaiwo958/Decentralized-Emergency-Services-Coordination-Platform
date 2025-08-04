;; Disaster Response Coordination Contract
;; Manages multi-agency response to disasters and major emergencies

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-DISASTER-NOT-FOUND (err u401))
(define-constant ERR-INVALID-SEVERITY (err u402))
(define-constant ERR-RESPONSE-NOT-FOUND (err u403))
(define-constant ERR-INVALID-STATUS (err u404))

;; Data Variables
(define-data-var next-disaster-id uint u1)
(define-data-var active-disasters uint u0)
(define-data-var total-responses uint u0)

;; Data Maps
(define-map disasters
  { disaster-id: uint }
  {
    disaster-type: (string-ascii 30),
    severity: uint,
    location: (string-ascii 100),
    affected-area: (string-ascii 200),
    description: (string-ascii 500),
    start-time: uint,
    estimated-duration: uint,
    status: (string-ascii 20),
    incident-commander: principal,
    agencies-involved: (list 10 (string-ascii 50)),
    resources-requested: (list 20 (string-ascii 50)),
    evacuation-zones: (list 5 (string-ascii 100))
  }
)

(define-map agency-responses
  { response-id: uint }
  {
    disaster-id: uint,
    agency: (string-ascii 50),
    response-type: (string-ascii 30),
    resources-deployed: (list 10 (string-ascii 50)),
    personnel-count: uint,
    deployment-time: uint,
    status: (string-ascii 20),
    estimated-completion: uint
  }
)

(define-map evacuation-orders
  { evacuation-id: uint }
  {
    disaster-id: uint,
    zone: (string-ascii 100),
    order-time: uint,
    evacuation-type: (string-ascii 20),
    estimated-population: uint,
    shelter-locations: (list 5 (string-ascii 100)),
    transportation-assets: (list 10 (string-ascii 50)),
    status: (string-ascii 20)
  }
)

(define-map authorized-commanders principal bool)
(define-map response-counter principal uint)
(define-map evacuation-counter principal uint)

;; Authorization Functions
(define-public (add-incident-commander (commander principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-commanders commander true))
  )
)

;; Disaster Declaration Functions
(define-public (declare-disaster
  (disaster-type (string-ascii 30))
  (severity uint)
  (location (string-ascii 100))
  (affected-area (string-ascii 200))
  (description (string-ascii 500))
  (estimated-duration uint)
  (agencies-involved (list 10 (string-ascii 50)))
  (evacuation-zones (list 5 (string-ascii 100))))
  (let
    (
      (disaster-id (var-get next-disaster-id))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (default-to false (map-get? authorized-commanders tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= severity u1) (<= severity u5)) ERR-INVALID-SEVERITY)

    (map-set disasters
      { disaster-id: disaster-id }
      {
        disaster-type: disaster-type,
        severity: severity,
        location: location,
        affected-area: affected-area,
        description: description,
        start-time: current-time,
        estimated-duration: estimated-duration,
        status: "active",
        incident-commander: tx-sender,
        agencies-involved: agencies-involved,
        resources-requested: (list),
        evacuation-zones: evacuation-zones
      }
    )

    (var-set next-disaster-id (+ disaster-id u1))
    (var-set active-disasters (+ (var-get active-disasters) u1))

    (ok disaster-id)
  )
)

(define-public (update-disaster-status
  (disaster-id uint)
  (new-status (string-ascii 20)))
  (let
    (
      (disaster-data (unwrap! (map-get? disasters { disaster-id: disaster-id }) ERR-DISASTER-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get incident-commander disaster-data)) ERR-NOT-AUTHORIZED)

    (if (is-eq new-status "resolved")
      (var-set active-disasters (- (var-get active-disasters) u1))
      true
    )

    (ok (map-set disasters
      { disaster-id: disaster-id }
      (merge disaster-data { status: new-status })
    ))
  )
)

;; Agency Response Functions
(define-public (deploy-agency-response
  (disaster-id uint)
  (agency (string-ascii 50))
  (response-type (string-ascii 30))
  (resources-deployed (list 10 (string-ascii 50)))
  (personnel-count uint)
  (estimated-completion uint))
  (let
    (
      (disaster-data (unwrap! (map-get? disasters { disaster-id: disaster-id }) ERR-DISASTER-NOT-FOUND))
      (response-id (+ (default-to u0 (map-get? response-counter tx-sender)) u1))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (default-to false (map-get? authorized-commanders tx-sender)) ERR-NOT-AUTHORIZED)

    (map-set agency-responses
      { response-id: response-id }
      {
        disaster-id: disaster-id,
        agency: agency,
        response-type: response-type,
        resources-deployed: resources-deployed,
        personnel-count: personnel-count,
        deployment-time: current-time,
        status: "deployed",
        estimated-completion: estimated-completion
      }
    )

    (map-set response-counter tx-sender response-id)
    (var-set total-responses (+ (var-get total-responses) u1))

    (ok response-id)
  )
)

(define-public (update-response-status
  (response-id uint)
  (new-status (string-ascii 20)))
  (let
    (
      (response-data (unwrap! (map-get? agency-responses { response-id: response-id }) ERR-RESPONSE-NOT-FOUND))
    )
    (asserts! (default-to false (map-get? authorized-commanders tx-sender)) ERR-NOT-AUTHORIZED)

    (ok (map-set agency-responses
      { response-id: response-id }
      (merge response-data { status: new-status })
    ))
  )
)

;; Evacuation Management Functions
(define-public (issue-evacuation-order
  (disaster-id uint)
  (zone (string-ascii 100))
  (evacuation-type (string-ascii 20))
  (estimated-population uint)
  (shelter-locations (list 5 (string-ascii 100)))
  (transportation-assets (list 10 (string-ascii 50))))
  (let
    (
      (disaster-data (unwrap! (map-get? disasters { disaster-id: disaster-id }) ERR-DISASTER-NOT-FOUND))
      (evacuation-id (+ (default-to u0 (map-get? evacuation-counter tx-sender)) u1))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (is-eq tx-sender (get incident-commander disaster-data)) ERR-NOT-AUTHORIZED)

    (map-set evacuation-orders
      { evacuation-id: evacuation-id }
      {
        disaster-id: disaster-id,
        zone: zone,
        order-time: current-time,
        evacuation-type: evacuation-type,
        estimated-population: estimated-population,
        shelter-locations: shelter-locations,
        transportation-assets: transportation-assets,
        status: "active"
      }
    )

    (map-set evacuation-counter tx-sender evacuation-id)
    (ok evacuation-id)
  )
)

(define-public (update-evacuation-status
  (evacuation-id uint)
  (new-status (string-ascii 20)))
  (let
    (
      (evacuation-data (unwrap! (map-get? evacuation-orders { evacuation-id: evacuation-id }) ERR-RESPONSE-NOT-FOUND))
      (disaster-data (unwrap! (map-get? disasters { disaster-id: (get disaster-id evacuation-data) }) ERR-DISASTER-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get incident-commander disaster-data)) ERR-NOT-AUTHORIZED)

    (ok (map-set evacuation-orders
      { evacuation-id: evacuation-id }
      (merge evacuation-data { status: new-status })
    ))
  )
)

;; Resource Coordination Functions
(define-public (request-mutual-aid
  (disaster-id uint)
  (requesting-agency (string-ascii 50))
  (resource-type (string-ascii 30))
  (quantity uint)
  (priority uint))
  (let
    (
      (disaster-data (unwrap! (map-get? disasters { disaster-id: disaster-id }) ERR-DISASTER-NOT-FOUND))
    )
    (asserts! (default-to false (map-get? authorized-commanders tx-sender)) ERR-NOT-AUTHORIZED)
    ;; Simplified mutual aid request - would implement complex coordination logic
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-disaster-info (disaster-id uint))
  (map-get? disasters { disaster-id: disaster-id })
)

(define-read-only (get-agency-response (response-id uint))
  (map-get? agency-responses { response-id: response-id })
)

(define-read-only (get-evacuation-order (evacuation-id uint))
  (map-get? evacuation-orders { evacuation-id: evacuation-id })
)

(define-read-only (get-active-disasters)
  (var-get active-disasters)
)

(define-read-only (get-total-responses)
  (var-get total-responses)
)

(define-read-only (is-authorized-commander (commander principal))
  (default-to false (map-get? authorized-commanders commander))
)

(define-read-only (get-disaster-severity-level (disaster-id uint))
  (match (map-get? disasters { disaster-id: disaster-id })
    disaster-data (get severity disaster-data)
    u0
  )
)

(define-read-only (calculate-resource-needs
  (disaster-type (string-ascii 30))
  (severity uint)
  (affected-population uint))
  ;; Simplified resource calculation
  {
    personnel: (* affected-population u2),
    vehicles: (/ affected-population u100),
    shelters: (/ affected-population u50)
  }
)

(define-read-only (get-evacuation-progress (evacuation-id uint))
  (match (map-get? evacuation-orders { evacuation-id: evacuation-id })
    evacuation-data (get status evacuation-data)
    "not-found"
  )
)
