
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

;; Add Candidate to Election
(define-public (add-candidate
  (election-id uint)
  (candidate-id uint)
  (name (string-ascii 100))
  (party (string-ascii 100))
  (metadata-uri (string-ascii 200))
)
  (begin
    ;; Only contract owner can add candidates
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    
    ;; Validate election exists
    (asserts! 
      (is-some (map-get? ElectionDetails election-id)) 
      ERR-INVALID-ELECTION
    )
    
    ;; Add candidate
    (map-set CandidateRegistry 
      { election-id: election-id, candidate-id: candidate-id }
      {
        name: name,
        party: party,
        vote-count: u0,
        metadata-uri: metadata-uri
      }
    )
    
    ;; Update total candidates
    (map-set ElectionDetails election-id
      (merge 
        (unwrap! (map-get? ElectionDetails election-id) ERR-INVALID-ELECTION)
        { total-candidates: (+ (get total-candidates 
            (unwrap! (map-get? ElectionDetails election-id) ERR-INVALID-ELECTION)) 
          u1) }
      )
    )
    
    (ok true)
  )
)

;; Delegation Map
(define-map VoteDelegation
  {
    delegator: principal,
    election-id: uint
  }
  {
    delegate: principal,
    delegation-timestamp: uint
  }
)

;; Delegate Voting Rights
(define-public (delegate-vote
  (election-id uint)
  (delegate principal)
)
  (let 
    (
      (delegator tx-sender)
      (voter-info (unwrap! 
        (map-get? VoterRegistry delegator) 
        ERR-INVALID-VOTER
      ))
    )
    ;; Validate delegation
    (asserts! (not (is-eq delegator delegate)) (err u6))
    (asserts! (get is-registered voter-info) ERR-INVALID-VOTER)
    (asserts! (not (get has-voted voter-info)) ERR-ALREADY-VOTED)
    
    ;; Record delegation
    (map-set VoteDelegation 
      { 
        delegator: delegator, 
        election-id: election-id 
      }
      {
        delegate: delegate,
        delegation-timestamp: stacks-block-height
      }
    )
    
    (ok true)
  )
)

;; Voter Verification Proof Map
(define-map VoterVerificationProof
  principal
  {
    verification-method: (string-ascii 50),
    proof-hash: (buff 32),
    verified-at: uint
  }
)

;; Add Verification Proof
(define-public (add-voter-verification-proof
  (verification-method (string-ascii 50))
  (proof-hash (buff 32))
)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    
    (map-set VoterVerificationProof tx-sender {
      verification-method: verification-method,
      proof-hash: proof-hash,
      verified-at: stacks-block-height
    })
    
    (ok true)
  )
)

;; Election Audit Log
(define-map ElectionAuditLog
  {
    election-id: uint,
    log-type: (string-ascii 50)
  }
  {
    details: (string-ascii 500),
    timestamp: uint
  }
)

;; Log Election Event
(define-public (log-election-event
  (election-id uint)
  (log-type (string-ascii 50))
  (details (string-ascii 500))
)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    
    (map-set ElectionAuditLog 
      {
        election-id: election-id,
        log-type: log-type
      }
      {
        details: details,
        timestamp: stacks-block-height
      }
    )
    
    (ok true)
  )
)


;; Election Challenge Map
(define-map ElectionChallenge
  {
    election-id: uint,
    challenger: principal
  }
  {
    challenge-reason: (string-ascii 200),
    challenge-timestamp: uint,
    status: uint,
    resolution-details: (optional (string-ascii 200))
  }
)

;; Challenge Election Results
(define-public (challenge-election
  (election-id uint)
  (challenge-reason (string-ascii 200))
)
  (begin
    ;; Validate election is completed
    (asserts! 
      (is-eq 
        (get status 
          (unwrap! 
            (map-get? ElectionDetails election-id) 
            ERR-INVALID-ELECTION
          )
        )
        STATUS-COMPLETED
      )
      (err u7)
    )
    
    (map-set ElectionChallenge 
      {
        election-id: election-id,
        challenger: tx-sender
      }
      {
        challenge-reason: challenge-reason,
        challenge-timestamp: stacks-block-height,
        status: u0,  ;; Pending
        resolution-details: none
      }
    )
    
    (ok true)
  )
)

;; Voting Weight Tiers
(define-constant VOTING-TIER-CITIZEN u1)
(define-constant VOTING-TIER-EXPERT u2)
(define-constant VOTING-TIER-STAKEHOLDER u3)

;; Voting Weight Tier Map
(define-map VotingWeightTiers
  principal
  {
    tier: uint,
    base-weight: uint,
    special-privileges: (list 10 (string-ascii 50))
  }
)

;; Assign Voting Weight Tier
(define-public (assign-voting-tier
  (voter principal)
  (tier uint)
  (base-weight uint)
  (special-privileges (list 10 (string-ascii 50)))
)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    
    (map-set VotingWeightTiers voter {
      tier: tier,
      base-weight: base-weight,
      special-privileges: special-privileges
    })
    
    (ok true)
  )
)

;; Election Configuration Extended
(define-map ElectionAdvancedConfig
  uint  ;; Election ID
  {
    voting-mechanism: uint,
    privacy-level: uint,
    minimum-participation-threshold: uint,
    voter-eligibility-criteria: (string-ascii 200),
    geo-restrictions: (optional (list 10 (string-ascii 50)))
  }
)

;; Configure Advanced Election Parameters
(define-public (configure-advanced-election
  (election-id uint)
  (voting-mechanism uint)
  (privacy-level uint)
  (min-participation uint)
  (eligibility-criteria (string-ascii 200))
  (geo-restrictions (optional (list 10 (string-ascii 50))))
)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    
    (map-set ElectionAdvancedConfig election-id {
      voting-mechanism: voting-mechanism,
      privacy-level: privacy-level,
      minimum-participation-threshold: min-participation,
      voter-eligibility-criteria: eligibility-criteria,
      geo-restrictions: geo-restrictions
    })
    
    (ok true)
  )
)

;; Encrypted Vote Storage
(define-map EncryptedVotes
  {
    election-id: uint,
    voter: principal
  }
  {
    encrypted-vote: (buff 256),
    encryption-public-key: (buff 256),
    vote-commitment-hash: (buff 32)
  }
)

;; Submit Encrypted Vote
(define-public (submit-encrypted-vote
  (election-id uint)
  (encrypted-vote (buff 256))
  (encryption-public-key (buff 256))
  (vote-commitment-hash (buff 32))
)
  (let 
    (
      (voter tx-sender)
      (voter-info (unwrap! 
        (map-get? VoterRegistry voter) 
        ERR-INVALID-VOTER
      ))
    )
    ;; Validate vote submission
    (asserts! (get is-registered voter-info) ERR-INVALID-VOTER)
    (asserts! (not (get has-voted voter-info)) ERR-ALREADY-VOTED)
    
    ;; Store encrypted vote
    (map-set EncryptedVotes 
      { 
        election-id: election-id, 
        voter: voter 
      }
      {
        encrypted-vote: encrypted-vote,
        encryption-public-key: encryption-public-key,
        vote-commitment-hash: vote-commitment-hash
      }
    )
    
    (ok true)
  )
)


