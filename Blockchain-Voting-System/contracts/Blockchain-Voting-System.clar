
;; title: Blockchain-Voting-System

;; Constants and Error Codes
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u1))
(define-constant ERR-INVALID-VOTER (err u2))
(define-constant ERR-VOTING-CLOSED (err u3))
(define-constant ERR-ALREADY-VOTED (err u4))
(define-constant ERR-INVALID-ELECTION (err u5))

