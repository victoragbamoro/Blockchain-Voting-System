
;; title: Blockchain-Voting-System

;; Constants and Error Codes
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u1))
(define-constant ERR-INVALID-VOTER (err u2))
(define-constant ERR-VOTING-CLOSED (err u3))
(define-constant ERR-ALREADY-VOTED (err u4))
(define-constant ERR-INVALID-ELECTION (err u5))

;; Election Status Enum
(define-constant STATUS-PENDING u0)
(define-constant STATUS-ACTIVE u1)
(define-constant STATUS-COMPLETED u2)

;; Voter Verification Map
(define-map VoterRegistry
  principal
  {
    is-registered: bool,
    voting-weight: uint,
    has-voted: bool
  }
)

;; Election Configuration Map
(define-map ElectionDetails
  uint  ;; Election ID
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    start-block: uint,
    end-block: uint,
    status: uint,
    total-voters: uint,
    total-candidates: uint
  }
)

;; Candidate Registry Map
(define-map CandidateRegistry
  {
    election-id: uint,
    candidate-id: uint
  }
  {
    name: (string-ascii 100),
    party: (string-ascii 100),
    vote-count: uint,
    metadata-uri: (string-ascii 200)
  }
)


;; Voting Record Map
(define-map VotingRecord
  {
    election-id: uint,
    voter: principal
  }
  {
    candidate-id: uint,
    timestamp: uint
  }
)

;; Track total number of elections
(define-data-var total-elections uint u0)

;; Election State Transition Function
(define-public (update-election-status 
  (election-id uint)
  (new-status uint)
)
  (begin
    ;; Only contract owner can update status
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    
    ;; Validate status transition
    (asserts! 
      (or 
        (is-eq new-status STATUS-ACTIVE)
        (is-eq new-status STATUS-COMPLETED)
      ) 
      ERR-INVALID-ELECTION
    )
    
    ;; Update election status
    (map-set ElectionDetails election-id 
      (merge 
        (unwrap! (map-get? ElectionDetails election-id) ERR-INVALID-ELECTION)
        { status: new-status }
      )
    )
    
    (ok true)
  )
)