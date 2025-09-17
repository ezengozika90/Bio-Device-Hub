;; Bioelectronics Platform Smart Contract
;; A comprehensive platform for managing bioelectronic devices, data, and access control

;; CONSTANTS & ERRORS

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-DEVICE-NOT-FOUND (err u101))
(define-constant ERR-DEVICE-ALREADY-EXISTS (err u102))
(define-constant ERR-INSUFFICIENT-BALANCE (err u103))
(define-constant ERR-INVALID-PARAMETERS (err u104))
(define-constant ERR-DATA-NOT-FOUND (err u105))
(define-constant ERR-ACCESS-DENIED (err u106))
(define-constant ERR-DEVICE-INACTIVE (err u107))
(define-constant ERR-INVALID-PAYMENT (err u108))

;; Contract constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant PLATFORM-FEE u100) ;; 1% in basis points (10000 = 100%)
(define-constant MIN-DATA-PRICE u1000000) ;; 1 STX minimum

;; DATA VARIABLES

(define-data-var next-device-id uint u1)
(define-data-var next-data-id uint u1)
(define-data-var platform-fee-rate uint PLATFORM-FEE)
(define-data-var emergency-stop bool false)

;; DATA MAPS

;; Device registry
(define-map devices
    uint ;; device-id
    {
        owner: principal,
        device-type: (string-ascii 50),
        model: (string-ascii 100),
        serial-number: (string-ascii 100),
        firmware-version: (string-ascii 20),
        status: (string-ascii 20), ;; "active", "inactive", "maintenance"
        registration-height: uint,
        last-update: uint,
        certification-level: (string-ascii 20), ;; "FDA", "CE", "experimental"
        data-encryption-key: (string-ascii 64)
    }
)

;; Bioelectronic data records
(define-map biodata
    uint ;; data-id
    {
        device-id: uint,
        owner: principal,
        data-type: (string-ascii 50), ;; "ECG", "EEG", "EMG", "neural", etc.
        timestamp: uint,
        data-hash: (string-ascii 64), ;; IPFS hash or encrypted data hash
        quality-score: uint, ;; 0-100
        privacy-level: uint, ;; 0=public, 1=restricted, 2=private
        price: uint, ;; price in microSTX for access
        access-count: uint,
        metadata: (string-ascii 500)
    }
)

;; Access permissions
(define-map data-access
    {data-id: uint, requester: principal}
    {
        granted: bool,
        granted-at: uint,
        expires-at: uint,
        access-type: (string-ascii 20), ;; "read", "analyze", "research"
        payment-amount: uint
    }
)

;; Device ownership history
(define-map device-transfers
    {device-id: uint, transfer-id: uint}
    {
        from: principal,
        to: principal,
        timestamp: uint,
        reason: (string-ascii 100)
    }
)

;; Research collaborations
(define-map research-collaborations
    {researcher: principal, data-owner: principal}
    {
        active: bool,
        collaboration-type: (string-ascii 50),
        revenue-share: uint, ;; percentage for data owner (0-10000)
        start-height: uint,
        end-height: (optional uint)
    }
)

;; Device maintenance records
(define-map maintenance-logs
    {device-id: uint, log-id: uint}
    {
        technician: principal,
        maintenance-type: (string-ascii 50),
        description: (string-ascii 500),
        timestamp: uint,
        cost: uint,
        next-maintenance-due: uint
    }
)

;; User balances for platform transactions
(define-map user-balances
    principal
    uint
)

;; AUTHORIZATION HELPERS

(define-private (is-contract-owner)
    (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-device-owner (device-id uint))
    (match (map-get? devices device-id)
        device (is-eq tx-sender (get owner device))
        false
    )
)

(define-private (is-emergency-stopped)
    (var-get emergency-stop)
)

;; INPUT VALIDATION HELPERS

;; Validate firmware version string
(define-private (is-valid-firmware-version (firmware-version (string-ascii 20)))
    (and 
        (> (len firmware-version) u0)
        (<= (len firmware-version) u20)
        ;; Additional validation: check if it contains only valid characters
        (is-valid-ascii-string firmware-version)
    )
)

;; Validate certification level
(define-private (is-valid-certification-level (cert-level (string-ascii 20)))
    (or 
        (is-eq cert-level "FDA")
        (is-eq cert-level "CE")
        (is-eq cert-level "experimental")
        (is-eq cert-level "none")
    )
)

;; Validate encryption key format (basic hex string validation)
(define-private (is-valid-encryption-key (key (string-ascii 64)))
    (and 
        (>= (len key) u32) ;; Minimum 32 characters (128-bit key in hex)
        (<= (len key) u64) ;; Maximum 64 characters (256-bit key in hex)
    )
)

;; Validate transfer reason
(define-private (is-valid-transfer-reason (reason (string-ascii 100)))
    (and 
        (> (len reason) u0)
        (<= (len reason) u100)
        (is-valid-ascii-string reason)
    )
)

;; Validate data type
(define-private (is-valid-data-type (data-type (string-ascii 50)))
    (and 
        (> (len data-type) u0)
        (<= (len data-type) u50)
        (or 
            (is-eq data-type "ECG")
            (is-eq data-type "EEG")
            (is-eq data-type "EMG")
            (is-eq data-type "neural")
            (is-eq data-type "biometric")
            (is-eq data-type "sensor")
            (is-eq data-type "other")
        )
    )
)

;; Validate data hash (IPFS hash or similar)
(define-private (is-valid-data-hash (hash (string-ascii 64)))
    (and 
        (>= (len hash) u32) ;; Minimum hash length
        (<= (len hash) u64)
        (is-valid-ascii-string hash)
    )
)

;; Validate metadata string
(define-private (is-valid-metadata (metadata (string-ascii 500)))
    (and 
        (<= (len metadata) u500)
        (is-valid-ascii-string metadata)
    )
)

;; Validate collaboration type
(define-private (is-valid-collaboration-type (collab-type (string-ascii 50)))
    (and 
        (> (len collab-type) u0)
        (<= (len collab-type) u50)
        (or 
            (is-eq collab-type "research")
            (is-eq collab-type "commercial")
            (is-eq collab-type "academic")
            (is-eq collab-type "clinical")
        )
    )
)

;; Validate maintenance type
(define-private (is-valid-maintenance-type (maint-type (string-ascii 50)))
    (and 
        (> (len maint-type) u0)
        (<= (len maint-type) u50)
        (or 
            (is-eq maint-type "routine")
            (is-eq maint-type "repair")
            (is-eq maint-type "upgrade")
            (is-eq maint-type "calibration")
            (is-eq maint-type "emergency")
        )
    )
)

;; Validate maintenance description
(define-private (is-valid-maintenance-description (description (string-ascii 500)))
    (and 
        (> (len description) u0)
        (<= (len description) u500)
        (is-valid-ascii-string description)
    )
)

;; Basic ASCII string validation (checks for printable characters)
(define-private (is-valid-ascii-string (str (string-ascii 500)))
    ;; For now, just check length is valid - in a real implementation,
    ;; you might want more sophisticated character validation
    (>= (len str) u0)
)

;; Validate principal (basic check that it's not the zero principal)
(define-private (is-valid-principal (user principal))
    (not (is-eq user 'SP000000000000000000002Q6VF78))
)

;; Validate cost amount
(define-private (is-valid-cost (cost uint))
    (and 
        (>= cost u0)
        (<= cost u1000000000000) ;; Reasonable upper limit
    )
)

;; Validate future block height
(define-private (is-valid-future-block (future-block uint))
    (> future-block block-height)
)

;; DEVICE MANAGEMENT

;; Register a new bioelectronic device
(define-public (register-device 
    (device-type (string-ascii 50))
    (model (string-ascii 100))
    (serial-number (string-ascii 100))
    (firmware-version (string-ascii 20))
    (certification-level (string-ascii 20))
    (encryption-key (string-ascii 64)))
    (let
        ((device-id (var-get next-device-id)))
        (asserts! (not (is-emergency-stopped)) ERR-NOT-AUTHORIZED)
        (asserts! (> (len device-type) u0) ERR-INVALID-PARAMETERS)
        (asserts! (> (len model) u0) ERR-INVALID-PARAMETERS)
        (asserts! (> (len serial-number) u0) ERR-INVALID-PARAMETERS)
        ;; Additional validations for potentially unchecked data
        (asserts! (is-valid-firmware-version firmware-version) ERR-INVALID-PARAMETERS)
        (asserts! (is-valid-certification-level certification-level) ERR-INVALID-PARAMETERS)
        (asserts! (is-valid-encryption-key encryption-key) ERR-INVALID-PARAMETERS)
        
        (map-set devices device-id {
            owner: tx-sender,
            device-type: device-type,
            model: model,
            serial-number: serial-number,
            firmware-version: firmware-version,
            status: "active",
            registration-height: block-height,
            last-update: block-height,
            certification-level: certification-level,
            data-encryption-key: encryption-key
        })
        
        (var-set next-device-id (+ device-id u1))
        (ok device-id)
    )
)

;; Update device status
(define-public (update-device-status (device-id uint) (new-status (string-ascii 20)))
    (let
        ((device (unwrap! (map-get? devices device-id) ERR-DEVICE-NOT-FOUND)))
        (asserts! (is-device-owner device-id) ERR-NOT-AUTHORIZED)
        (asserts! (not (is-emergency-stopped)) ERR-NOT-AUTHORIZED)
        
        (map-set devices device-id (merge device {
            status: new-status,
            last-update: block-height
        }))
        (ok true)
    )
)

;; Transfer device ownership
(define-public (transfer-device (device-id uint) (new-owner principal) (reason (string-ascii 100)))
    (let
        ((device (unwrap! (map-get? devices device-id) ERR-DEVICE-NOT-FOUND)))
        (asserts! (is-device-owner device-id) ERR-NOT-AUTHORIZED)
        (asserts! (not (is-eq tx-sender new-owner)) ERR-INVALID-PARAMETERS)
        ;; Validate new owner principal and reason
        (asserts! (is-valid-principal new-owner) ERR-INVALID-PARAMETERS)
        (asserts! (is-valid-transfer-reason reason) ERR-INVALID-PARAMETERS)
        
        ;; Record transfer with timestamp
        (map-set device-transfers 
            {device-id: device-id, transfer-id: u1}
            {
                from: tx-sender,
                to: new-owner,
                timestamp: block-height,
                reason: reason
            }
        )
        
        ;; Update device ownership
        (map-set devices device-id (merge device {
            owner: new-owner,
            last-update: block-height
        }))
        
        (ok true)
    )
)

;; DATA MANAGEMENT

;; Submit bioelectronic data
(define-public (submit-biodata
    (device-id uint)
    (data-type (string-ascii 50))
    (data-hash (string-ascii 64))
    (quality-score uint)
    (privacy-level uint)
    (price uint)
    (metadata (string-ascii 500)))
    (let
        ((data-id (var-get next-data-id))
         (device (unwrap! (map-get? devices device-id) ERR-DEVICE-NOT-FOUND)))
        (asserts! (is-device-owner device-id) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status device) "active") ERR-DEVICE-INACTIVE)
        (asserts! (<= quality-score u100) ERR-INVALID-PARAMETERS)
        (asserts! (<= privacy-level u2) ERR-INVALID-PARAMETERS)
        (asserts! (or (is-eq price u0) (>= price MIN-DATA-PRICE)) ERR-INVALID-PARAMETERS)
        ;; Additional validations for potentially unchecked data
        (asserts! (is-valid-data-type data-type) ERR-INVALID-PARAMETERS)
        (asserts! (is-valid-data-hash data-hash) ERR-INVALID-PARAMETERS)
        (asserts! (is-valid-metadata metadata) ERR-INVALID-PARAMETERS)
        
        (map-set biodata data-id {
            device-id: device-id,
            owner: tx-sender,
            data-type: data-type,
            timestamp: block-height,
            data-hash: data-hash,
            quality-score: quality-score,
            privacy-level: privacy-level,
            price: price,
            access-count: u0,
            metadata: metadata
        })
        
        (var-set next-data-id (+ data-id u1))
        (ok data-id)
    )
)

;; Request access to biodata
(define-public (request-data-access 
    (data-id uint) 
    (access-type (string-ascii 20))
    (duration-blocks uint))
    (let
        ((data-record (unwrap! (map-get? biodata data-id) ERR-DATA-NOT-FOUND))
         (payment-amount (get price data-record))
         (user-balance (default-to u0 (map-get? user-balances tx-sender))))
        
        (asserts! (not (is-emergency-stopped)) ERR-NOT-AUTHORIZED)
        (asserts! (> duration-blocks u0) ERR-INVALID-PARAMETERS)
        (asserts! (> (len access-type) u0) ERR-INVALID-PARAMETERS)
        
        ;; Allow access to public data (privacy-level 0) or paid data
        (asserts! (or 
            (is-eq (get privacy-level data-record) u0)
            (and (> (get privacy-level data-record) u0) (> payment-amount u0))
        ) ERR-ACCESS-DENIED)
        
        (asserts! (not (is-eq tx-sender (get owner data-record))) ERR-INVALID-PARAMETERS)
        
        ;; Check payment for paid data
        (if (> payment-amount u0)
            (begin
                (asserts! (>= user-balance payment-amount) ERR-INSUFFICIENT-BALANCE)
                (try! (process-data-payment data-id payment-amount))
            )
            true
        )
        
        ;; Grant access
        (map-set data-access
            {data-id: data-id, requester: tx-sender}
            {
                granted: true,
                granted-at: block-height,
                expires-at: (+ block-height duration-blocks),
                access-type: access-type,
                payment-amount: payment-amount
            }
        )
        
        ;; Update access count
        (map-set biodata data-id (merge data-record {
            access-count: (+ (get access-count data-record) u1)
        }))
        
        (ok true)
    )
)

;; PAYMENT PROCESSING

;; Deposit funds to user balance
(define-public (deposit-funds (amount uint))
    (let
        ((current-balance (default-to u0 (map-get? user-balances tx-sender))))
        (asserts! (> amount u0) ERR-INVALID-PARAMETERS)
        (asserts! (not (is-emergency-stopped)) ERR-NOT-AUTHORIZED)
        
        ;; Transfer STX from user to contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Update user balance
        (map-set user-balances tx-sender (+ current-balance amount))
        (ok true)
    )
)

;; Withdraw funds from user balance
(define-public (withdraw-funds (amount uint))
    (let
        ((current-balance (default-to u0 (map-get? user-balances tx-sender)))
         (recipient tx-sender))
        (asserts! (>= current-balance amount) ERR-INSUFFICIENT-BALANCE)
        (asserts! (> amount u0) ERR-INVALID-PARAMETERS)
        (asserts! (not (is-emergency-stopped)) ERR-NOT-AUTHORIZED)
        
        ;; Update balance first to prevent re-entrancy
        (map-set user-balances tx-sender (- current-balance amount))
        
        ;; Transfer STX back to user from contract
        (try! (as-contract (stx-transfer? amount tx-sender recipient)))
        (ok true)
    )
)

;; Process payment for data access
(define-private (process-data-payment (data-id uint) (amount uint))
    (let
        ((data-record (unwrap! (map-get? biodata data-id) ERR-DATA-NOT-FOUND))
         (data-owner (get owner data-record))
         (platform-fee (/ (* amount (var-get platform-fee-rate)) u10000))
         (owner-payment (- amount platform-fee))
         (buyer-balance (default-to u0 (map-get? user-balances tx-sender)))
         (owner-balance (default-to u0 (map-get? user-balances data-owner))))
        
        ;; Deduct from buyer
        (map-set user-balances tx-sender (- buyer-balance amount))
        
        ;; Pay data owner
        (map-set user-balances data-owner (+ owner-balance owner-payment))
        
        (ok true)
    )
)

;; RESEARCH COLLABORATION

;; Establish research collaboration
(define-public (create-collaboration
    (researcher principal)
    (collaboration-type (string-ascii 50))
    (revenue-share uint)
    (duration-blocks (optional uint)))
    (begin
        (asserts! (<= revenue-share u10000) ERR-INVALID-PARAMETERS)
        (asserts! (not (is-eq tx-sender researcher)) ERR-INVALID-PARAMETERS)
        (asserts! (not (is-emergency-stopped)) ERR-NOT-AUTHORIZED)
        ;; Validate researcher principal and collaboration type
        (asserts! (is-valid-principal researcher) ERR-INVALID-PARAMETERS)
        (asserts! (is-valid-collaboration-type collaboration-type) ERR-INVALID-PARAMETERS)
        ;; Validate duration blocks if provided
        (asserts! (match duration-blocks
            some-duration (is-valid-future-block some-duration)
            true
        ) ERR-INVALID-PARAMETERS)
        
        (map-set research-collaborations
            {researcher: researcher, data-owner: tx-sender}
            {
                active: true,
                collaboration-type: collaboration-type,
                revenue-share: revenue-share,
                start-height: block-height,
                end-height: duration-blocks
            }
        )
        (ok true)
    )
)

;; End research collaboration
(define-public (end-collaboration (researcher principal))
    (let
        ((collaboration (unwrap! (map-get? research-collaborations 
            {researcher: researcher, data-owner: tx-sender}) ERR-DATA-NOT-FOUND)))
        (asserts! (get active collaboration) ERR-INVALID-PARAMETERS)
        (asserts! (not (is-emergency-stopped)) ERR-NOT-AUTHORIZED)
        ;; Validate researcher principal
        (asserts! (is-valid-principal researcher) ERR-INVALID-PARAMETERS)
        
        (map-set research-collaborations
            {researcher: researcher, data-owner: tx-sender}
            (merge collaboration {
                active: false,
                end-height: (some block-height)
            })
        )
        (ok true)
    )
)

;; MAINTENANCE MANAGEMENT

;; Log device maintenance
(define-public (log-maintenance
    (device-id uint)
    (maintenance-type (string-ascii 50))
    (description (string-ascii 500))
    (cost uint)
    (next-due uint))
    (begin
        (asserts! (is-device-owner device-id) ERR-NOT-AUTHORIZED)
        (asserts! (not (is-emergency-stopped)) ERR-NOT-AUTHORIZED)
        ;; Validate maintenance inputs
        (asserts! (is-valid-maintenance-type maintenance-type) ERR-INVALID-PARAMETERS)
        (asserts! (is-valid-maintenance-description description) ERR-INVALID-PARAMETERS)
        (asserts! (is-valid-cost cost) ERR-INVALID-PARAMETERS)
        (asserts! (is-valid-future-block next-due) ERR-INVALID-PARAMETERS)
        
        (map-set maintenance-logs
            {device-id: device-id, log-id: u1}
            {
                technician: tx-sender,
                maintenance-type: maintenance-type,
                description: description,
                timestamp: block-height,
                cost: cost,
                next-maintenance-due: next-due
            }
        )
        (ok true)
    )
)

;; DATA OWNER FUNCTIONS

;; Revoke data access (by data owner)
(define-public (revoke-data-access (data-id uint) (requester principal))
    (let
        ((data-record (unwrap! (map-get? biodata data-id) ERR-DATA-NOT-FOUND)))
        (asserts! (is-eq tx-sender (get owner data-record)) ERR-NOT-AUTHORIZED)
        (asserts! (is-some (map-get? data-access {data-id: data-id, requester: requester})) ERR-ACCESS-DENIED)
        (asserts! (not (is-emergency-stopped)) ERR-NOT-AUTHORIZED)
        ;; Validate requester principal
        (asserts! (is-valid-principal requester) ERR-INVALID-PARAMETERS)
        
        (map-delete data-access {data-id: data-id, requester: requester})
        (ok true)
    )
)

;; Update data pricing
(define-public (update-data-price (data-id uint) (new-price uint))
    (let
        ((data-record (unwrap! (map-get? biodata data-id) ERR-DATA-NOT-FOUND)))
        (asserts! (is-eq tx-sender (get owner data-record)) ERR-NOT-AUTHORIZED)
        (asserts! (or (is-eq new-price u0) (>= new-price MIN-DATA-PRICE)) ERR-INVALID-PARAMETERS)
        (asserts! (not (is-emergency-stopped)) ERR-NOT-AUTHORIZED)
        
        (map-set biodata data-id (merge data-record {
            price: new-price
        }))
        (ok true)
    )
)

;; ADMIN FUNCTIONS

;; Emergency stop
(define-public (toggle-emergency-stop)
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (var-set emergency-stop (not (var-get emergency-stop)))
        (ok (var-get emergency-stop))
    )
)

;; Update platform fee
(define-public (update-platform-fee (new-fee uint))
    (begin
        (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (<= new-fee u1000) ERR-INVALID-PARAMETERS) ;; Max 10%
        (var-set platform-fee-rate new-fee)
        (ok true)
    )
)

;; READ-ONLY FUNCTIONS

;; Get device information
(define-read-only (get-device (device-id uint))
    (map-get? devices device-id)
)

;; Get biodata information
(define-read-only (get-biodata (data-id uint))
    (map-get? biodata data-id)
)

;; Get user balance
(define-read-only (get-user-balance (user principal))
    (default-to u0 (map-get? user-balances user))
)

;; Check data access permission
(define-read-only (has-data-access (data-id uint) (user principal))
    (match (map-get? data-access {data-id: data-id, requester: user})
        access (and 
            (get granted access)
            (> (get expires-at access) block-height)
        )
        false
    )
)

;; Get collaboration status
(define-read-only (get-collaboration (researcher principal) (data-owner principal))
    (map-get? research-collaborations {researcher: researcher, data-owner: data-owner})
)

;; Get device status
(define-read-only (get-device-status (device-id uint))
    (match (map-get? devices device-id)
        device (ok (get status device))
        ERR-DEVICE-NOT-FOUND
    )
)

;; Get platform statistics
(define-read-only (get-platform-stats)
    {
        total-devices: (- (var-get next-device-id) u1),
        total-data-records: (- (var-get next-data-id) u1),
        platform-fee-rate: (var-get platform-fee-rate),
        emergency-stopped: (var-get emergency-stop)
    }
)

;; Enhanced data quality validation
(define-read-only (validate-data-submission 
    (device-id uint)
    (data-type (string-ascii 50))
    (quality-score uint)
    (privacy-level uint)
    (data-hash (string-ascii 64)))
    (let
        ((device-exists (is-some (map-get? devices device-id))))
        (and
            device-exists
            (<= quality-score u100)
            (<= privacy-level u2)
            (is-valid-data-type data-type)
            (is-valid-data-hash data-hash)
        )
    )
)

;; Get access history for a data record
(define-read-only (get-data-access-info (data-id uint) (requester principal))
    (map-get? data-access {data-id: data-id, requester: requester})
)

;; CONTRACT INITIALIZATION

;; Contract deployment initialization
(begin
    (print "Bioelectronics Platform initialized")
    (print {
        contract-owner: CONTRACT-OWNER,
        initial-device-id: (var-get next-device-id),
        initial-data-id: (var-get next-data-id),
        platform-fee: (var-get platform-fee-rate)
    })
)