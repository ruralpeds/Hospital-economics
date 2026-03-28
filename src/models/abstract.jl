# Abstract type hierarchy for Rural Hospital Economics Simulator

abstract type AbstractEntity end
abstract type AbstractHospital <: AbstractEntity end
abstract type AbstractRuralHospital <: AbstractHospital end
abstract type AbstractUrbanHospital <: AbstractHospital end

# Hospital payment designations
abstract type AbstractPaymentDesignation end
struct CostBasedPayment <: AbstractPaymentDesignation end
struct ProspectivePayment <: AbstractPaymentDesignation end
struct REHPayment <: AbstractPaymentDesignation end
struct SoleCommunityPayment <: AbstractPaymentDesignation end

# Simulation methodology types
abstract type AbstractSimulationParams end
abstract type AbstractSimulationResult end

# Financial model types
abstract type AbstractFinancialModel end
abstract type AbstractReimbursementModel end
abstract type AbstractCostModel end

# Agent types for ABM
abstract type AbstractAgent end
abstract type AbstractPatientAgent <: AbstractAgent end
abstract type AbstractProviderAgent <: AbstractAgent end
abstract type AbstractPayerAgent <: AbstractAgent end
