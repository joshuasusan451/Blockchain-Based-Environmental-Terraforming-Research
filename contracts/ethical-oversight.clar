;; Ethical Oversight Contract
;; Ensures responsible terraforming research practices

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_ASSESSMENT_NOT_FOUND (err u401))
(define-constant ERR_INVALID_RATING (err u402))
(define-constant ERR_NOT_VERIFIED_INSTITUTION (err u403))

;; Ethical concern levels
(define-constant CONCERN_NONE u0)
(define-constant CONCERN_LOW u1)
(define-constant CONCERN_MEDIUM u2)
(define-constant CONCERN_HIGH u3)
(define-constant CONCERN_CRITICAL u4)

;; Assessment status
(define-constant STATUS_PENDING u0)
(define-constant STATUS_APPROVED u1)
(define-constant STATUS_CONDITIONAL u2)
(define-constant STATUS_REJECTED u3)

;; Data structures
(define-map ethical-assessments
  { assessment-id: uint }
  {
    protocol-id: uint,
    institution-id: uint,
    environmental-impact: uint,
    indigenous-rights: uint,
    biodiversity-concern: uint,
    long-term-effects: uint,
    reversibility: uint,
    consent-obtained: bool,
    risk-mitigation: (string-ascii 1000),
    ethical-committee-review: bool,
    overall-rating: uint,
    status: uint,
    assessment-date: uint,
    reviewer-principal: principal
  }
)

(define-map ethical-guidelines
  { guideline-id: uint }
  {
    title: (string-ascii 200),
    description: (string-ascii 2000),
    category: (string-ascii 100),
    mandatory: bool,
    creation-date: uint,
    last-updated: uint
  }
)

(define-map compliance-records
  { protocol-id: uint, guideline-id: uint }
  {
    compliant: bool,
    evidence: (string-ascii 500),
    verification-date: uint,
    verifier: principal
  }
)

(define-data-var next-assessment-id uint u1)
(define-data-var next-guideline-id uint u1)

;; Reference to institution verification contract
(define-trait institution-verifier-trait
  (
    (is-institution-verified (principal) (response bool uint))
  )
)

;; Submit ethical assessment
(define-public (submit-ethical-assessment
  (protocol-id uint)
  (environmental-impact uint)
  (indigenous-rights uint)
  (biodiversity-concern uint)
  (long-term-effects uint)
  (reversibility uint)
  (consent-obtained bool)
  (risk-mitigation (string-ascii 1000))
  (ethical-committee-review bool)
  (institution-verifier <institution-verifier-trait>))
  (let ((assessment-id (var-get next-assessment-id)))
    ;; Verify institution
    (asserts! (unwrap! (contract-call? institution-verifier is-institution-verified tx-sender) ERR_NOT_VERIFIED_INSTITUTION) ERR_NOT_VERIFIED_INSTITUTION)
    (asserts! (and (<= environmental-impact CONCERN_CRITICAL)
                   (<= indigenous-rights CONCERN_CRITICAL)
                   (<= biodiversity-concern CONCERN_CRITICAL)
                   (<= long-term-effects CONCERN_CRITICAL)
                   (<= reversibility CONCERN_CRITICAL)) ERR_INVALID_RATING)

    (let ((overall-rating (calculate-overall-rating environmental-impact indigenous-rights biodiversity-concern long-term-effects reversibility)))
      (map-set ethical-assessments
        { assessment-id: assessment-id }
        {
          protocol-id: protocol-id,
          institution-id: u0, ;; Would be populated from institution contract
          environmental-impact: environmental-impact,
          indigenous-rights: indigenous-rights,
          biodiversity-concern: biodiversity-concern,
          long-term-effects: long-term-effects,
          reversibility: reversibility,
          consent-obtained: consent-obtained,
          risk-mitigation: risk-mitigation,
          ethical-committee-review: ethical-committee-review,
          overall-rating: overall-rating,
          status: STATUS_PENDING,
          assessment-date: block-height,
          reviewer-principal: tx-sender
        }
      )
      (var-set next-assessment-id (+ assessment-id u1))
      (ok assessment-id)
    )
  )
)

;; Approve/reject ethical assessment
(define-public (review-ethical-assessment (assessment-id uint) (new-status uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-status STATUS_REJECTED) ERR_INVALID_RATING)
    (match (map-get? ethical-assessments { assessment-id: assessment-id })
      assessment-data
      (begin
        (map-set ethical-assessments
          { assessment-id: assessment-id }
          (merge assessment-data { status: new-status })
        )
        (ok true)
      )
      ERR_ASSESSMENT_NOT_FOUND
    )
  )
)

;; Create ethical guideline
(define-public (create-ethical-guideline
  (title (string-ascii 200))
  (description (string-ascii 2000))
  (category (string-ascii 100))
  (mandatory bool))
  (let ((guideline-id (var-get next-guideline-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set ethical-guidelines
      { guideline-id: guideline-id }
      {
        title: title,
        description: description,
        category: category,
        mandatory: mandatory,
        creation-date: block-height,
        last-updated: block-height
      }
    )
    (var-set next-guideline-id (+ guideline-id u1))
    (ok guideline-id)
  )
)

;; Record compliance
(define-public (record-compliance
  (protocol-id uint)
  (guideline-id uint)
  (compliant bool)
  (evidence (string-ascii 500))
  (institution-verifier <institution-verifier-trait>))
  (begin
    ;; Verify institution
    (asserts! (unwrap! (contract-call? institution-verifier is-institution-verified tx-sender) ERR_NOT_VERIFIED_INSTITUTION) ERR_NOT_VERIFIED_INSTITUTION)
    (map-set compliance-records
      { protocol-id: protocol-id, guideline-id: guideline-id }
      {
        compliant: compliant,
        evidence: evidence,
        verification-date: block-height,
        verifier: tx-sender
      }
    )
    (ok true)
  )
)

;; Helper function to calculate overall rating
(define-private (calculate-overall-rating
  (env-impact uint)
  (indigenous uint)
  (biodiversity uint)
  (long-term uint)
  (reversibility uint))
  (let ((total-score (+ env-impact indigenous biodiversity long-term reversibility)))
    (/ total-score u5)
  )
)

;; Get ethical assessment
(define-read-only (get-ethical-assessment (assessment-id uint))
  (map-get? ethical-assessments { assessment-id: assessment-id })
)

;; Get ethical guideline
(define-read-only (get-ethical-guideline (guideline-id uint))
  (map-get? ethical-guidelines { guideline-id: guideline-id })
)

;; Get compliance record
(define-read-only (get-compliance-record (protocol-id uint) (guideline-id uint))
  (map-get? compliance-records { protocol-id: protocol-id, guideline-id: guideline-id })
)

;; Check if protocol meets ethical standards
(define-read-only (meets-ethical-standards (assessment-id uint))
  (match (map-get? ethical-assessments { assessment-id: assessment-id })
    assessment-data
    (and (is-eq (get status assessment-data) STATUS_APPROVED)
         (<= (get overall-rating assessment-data) CONCERN_MEDIUM)
         (get consent-obtained assessment-data)
         (get ethical-committee-review assessment-data))
    false
  )
)
