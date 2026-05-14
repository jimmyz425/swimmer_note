import Foundation

extension CombinedToolExecutor {
    // MARK: - Tier Guidance Tool

    func getTierGuidance() throws -> String {
        guard let profile else {
            return try encodeJSON(["error": "No active profile"])
        }

        let tier = profile.trainingTier
        let subTier = profile.subTier

        // Get weekly and per-session distance based on tier/sub-tier
        let weeklyDistance = weeklyDistanceForTier(tier: tier, subTier: subTier)
        let perSessionDistance = perSessionDistanceForTier(tier: tier, subTier: subTier)
        let practicesPerWeek = practicesPerWeekForTier(tier: tier, subTier: subTier)
        let zoneDistribution = zoneDistributionForTier(tier: tier, subTier: subTier)
        let trainingFocus = trainingFocusForTier(tier: tier, subTier: subTier)

        let result: [String: Any] = [
            "tier": tier.displayName,
            "tier_raw": tier.rawValue,
            "sub_tier": subTier.displayName,
            "sub_tier_raw": subTier.rawValue,
            "full_level": fullLevelName(tier: tier, subTier: subTier),
            "weekly_distance": weeklyDistance,
            "per_session_distance": perSessionDistance,
            "practices_per_week": practicesPerWeek,
            "zone_distribution": zoneDistribution,
            "training_focus": trainingFocus,
            "guidance_source": "club-training-reference.md",
            "critical_notes": [
                "Zone distribution must be followed - higher tiers can handle more intensity",
                "Session total distance should not exceed per_session_distance max",
                "Weekly total across all sessions should align with weekly_distance target",
                "Training focus priorities should inform the main set structure"
            ]
        ]

        return try encodeJSON(result)
    }

    func weeklyDistanceForTier(tier: TrainingTier, subTier: SubTier) -> [String: Any] {
        switch tier {
        case .preCompetitive:
            switch subTier {
            case .a: return ["min": 1000, "max": 2500, "unit": "meters", "description": "1-2.5 km/week (Pre-Comp A: Foundations)"]
            case .b: return ["min": 2000, "max": 4000, "unit": "meters", "description": "2-4 km/week (Pre-Comp B: Skill Building)"]
            case .c: return ["min": 3000, "max": 7000, "unit": "meters", "description": "3-7 km/week (Pre-Comp C: Pre-Competitive)"]
            default: return ["min": 3000, "max": 8000, "unit": "meters", "description": "3-8 km/week"]
            }
        case .bronze:
            switch subTier {
            case .one: return ["min": 4500, "max": 7500, "unit": "meters", "description": "4.5-7.5 km/week (Bronze 1: First Year)"]
            case .two: return ["min": 6000, "max": 14000, "unit": "meters", "description": "6-14 km/week (Bronze 2: Toward B Times)"]
            case .three: return ["min": 10000, "max": 18000, "unit": "meters", "description": "10-18 km/week (Bronze 3: Has B Times)"]
            default: return ["min": 8000, "max": 18000, "unit": "meters", "description": "8-18 km/week"]
            }
        case .silver:
            switch subTier {
            case .one: return ["min": 10000, "max": 16000, "unit": "meters", "description": "10-16 km/week (Silver 1: Early Silver)"]
            case .two: return ["min": 12000, "max": 20000, "unit": "meters", "description": "12-20 km/week (Silver 2: Mid-Silver)"]
            case .three: return ["min": 14000, "max": 28000, "unit": "meters", "description": "14-28 km/week (Silver 3: Upper Silver)"]
            default: return ["min": 15000, "max": 28000, "unit": "meters", "description": "15-28 km/week"]
            }
        case .gold:
            return ["min": 25000, "max": 40000, "unit": "meters", "description": "25-40 km/week (Gold: Senior Age Group)"]
        case .senior:
            return ["min": 40000, "max": 60000, "unit": "meters", "description": "40-60 km/week (Senior: Championship)"]
        case .national:
            return ["min": 50000, "max": 80000, "unit": "meters", "description": "50-80+ km/week (National: Elite)"]
        }
    }

    func perSessionDistanceForTier(tier: TrainingTier, subTier: SubTier) -> [String: Any] {
        switch tier {
        case .preCompetitive:
            switch subTier {
            case .a: return ["min": 500, "max": 1200, "unit": "meters", "description": "500-1,200m per practice (30-45 min)"]
            case .b: return ["min": 1000, "max": 2000, "unit": "meters", "description": "1,000-2,000m per practice (45-60 min)"]
            case .c: return ["min": 1500, "max": 2500, "unit": "meters", "description": "1,500-2,500m per practice (45-60 min)"]
            default: return ["min": 500, "max": 2500, "unit": "meters"]
            }
        case .bronze:
            switch subTier {
            case .one: return ["min": 1500, "max": 2500, "unit": "meters", "description": "1,500-2,500m per practice (60 min)"]
            case .two: return ["min": 2000, "max": 3500, "unit": "meters", "description": "2,000-3,500m per practice (60-75 min)"]
            case .three: return ["min": 2500, "max": 4500, "unit": "meters", "description": "2,500-4,500m per practice (60-75 min)"]
            default: return ["min": 1500, "max": 4500, "unit": "meters"]
            }
        case .silver:
            switch subTier {
            case .one: return ["min": 2500, "max": 4000, "unit": "meters", "description": "2,500-4,000m per practice (75 min)"]
            case .two: return ["min": 3000, "max": 5000, "unit": "meters", "description": "3,000-5,000m per practice (75-90 min)"]
            case .three: return ["min": 3500, "max": 5500, "unit": "meters", "description": "3,500-5,500m per practice (75-90 min)"]
            default: return ["min": 2500, "max": 5500, "unit": "meters"]
            }
        case .gold:
            return ["min": 4500, "max": 7500, "unit": "meters", "description": "4,500-7,500m per practice (90-105 min)"]
        case .senior:
            return ["min": 5500, "max": 8500, "unit": "meters", "description": "5,500-8,500m per practice (90-120 min)"]
        case .national:
            return ["min": 5000, "max": 10000, "unit": "meters", "description": "5,000-10,000+ m per practice (120-180 min)"]
        }
    }

    func practicesPerWeekForTier(tier: TrainingTier, subTier: SubTier) -> [String: Any] {
        switch tier {
        case .preCompetitive:
            switch subTier {
            case .a: return ["min": 2, "max": 2, "recommended": 2]
            case .b: return ["min": 2, "max": 2, "recommended": 2]
            case .c: return ["min": 2, "max": 3, "recommended": 2]
            default: return ["min": 2, "max": 3, "recommended": 2]
            }
        case .bronze:
            switch subTier {
            case .one: return ["min": 3, "max": 3, "recommended": 3]
            case .two: return ["min": 3, "max": 4, "recommended": 3]
            case .three: return ["min": 4, "max": 4, "recommended": 4]
            default: return ["min": 3, "max": 4, "recommended": 3]
            }
        case .silver:
            switch subTier {
            case .one: return ["min": 4, "max": 4, "recommended": 4]
            case .two: return ["min": 4, "max": 4, "recommended": 4]
            case .three: return ["min": 4, "max": 5, "recommended": 4]
            default: return ["min": 4, "max": 5, "recommended": 4]
            }
        case .gold:
            return ["min": 5, "max": 6, "recommended": 5]
        case .senior:
            return ["min": 6, "max": 8, "recommended": 6]
        case .national:
            return ["min": 8, "max": 12, "recommended": 8]
        }
    }

    func zoneDistributionForTier(tier: TrainingTier, subTier: SubTier) -> [String: Any] {
        // Zone distribution based on USA Swimming club structure
        switch tier {
        case .preCompetitive:
            switch subTier {
            case .a:
                return [
                    "zone_0_recovery": "10-15%",
                    "zone_1_aerobic_base": "60-70%",
                    "zone_2_aerobic_endurance": "10-15%",
                    "zone_3_tempo": "0-5%",
                    "zone_4_threshold": "0%",
                    "zone_5_vo2max": "0%",
                    "zone_6_sprint": "0%",
                    "note": "Overwhelmingly Zone 1. No formal high-intensity training."
                ]
            case .b:
                return [
                    "zone_0_recovery": "10-15%",
                    "zone_1_aerobic_base": "55-65%",
                    "zone_2_aerobic_endurance": "15-20%",
                    "zone_3_tempo": "5-10%",
                    "zone_4_threshold": "0%",
                    "zone_5_vo2max": "0%",
                    "zone_6_sprint": "0%",
                    "note": "Still primarily Zone 1. Brief Zone 3 bursts only."
                ]
            case .c:
                return [
                    "zone_0_recovery": "10-15%",
                    "zone_1_aerobic_base": "55-60%",
                    "zone_2_aerobic_endurance": "15-20%",
                    "zone_3_tempo": "5-10%",
                    "zone_4_threshold": "0-5%",
                    "zone_5_vo2max": "0%",
                    "zone_6_sprint": "0%",
                    "note": "First exposure to Zone 4 for brief sprint games only."
                ]
            default:
                return [
                    "zone_0_recovery": "10-15%",
                    "zone_1_aerobic_base": "55-65%",
                    "zone_2_aerobic_endurance": "15-20%",
                    "zone_3_tempo": "5-10%",
                    "zone_4_threshold": "0-5%",
                    "zone_5_vo2max": "0%",
                    "zone_6_sprint": "0-5%"
                ]
            }
        case .bronze:
            switch subTier {
            case .one:
                return [
                    "zone_0_recovery": "10%",
                    "zone_1_aerobic_base": "55-60%",
                    "zone_2_aerobic_endurance": "15-20%",
                    "zone_3_tempo": "5-10%",
                    "zone_4_threshold": "0%",
                    "zone_5_vo2max": "0%",
                    "zone_6_sprint": "0%",
                    "note": "No threshold or sprint work. Focus on technique and easy swimming."
                ]
            case .two:
                return [
                    "zone_0_recovery": "10%",
                    "zone_1_aerobic_base": "50-55%",
                    "zone_2_aerobic_endurance": "20-25%",
                    "zone_3_tempo": "10-15%",
                    "zone_4_threshold": "0-5%",
                    "zone_5_vo2max": "0%",
                    "zone_6_sprint": "0%",
                    "note": "First introduction to Zone 4. Brief threshold pieces."
                ]
            case .three:
                return [
                    "zone_0_recovery": "10%",
                    "zone_1_aerobic_base": "45-50%",
                    "zone_2_aerobic_endurance": "25-30%",
                    "zone_3_tempo": "10-15%",
                    "zone_4_threshold": "5%",
                    "zone_5_vo2max": "0%",
                    "zone_6_sprint": "0%",
                    "note": "Regular Zone 3-4 work. Preparing for Silver-level intensity."
                ]
            default:
                return [
                    "zone_0_recovery": "10%",
                    "zone_1_aerobic_base": "50-55%",
                    "zone_2_aerobic_endurance": "20-25%",
                    "zone_3_tempo": "10-15%",
                    "zone_4_threshold": "0-5%",
                    "zone_5_vo2max": "0%",
                    "zone_6_sprint": "0%"
                ]
            }
        case .silver:
            switch subTier {
            case .one:
                return [
                    "zone_0_recovery": "10%",
                    "zone_1_aerobic_base": "45-50%",
                    "zone_2_aerobic_endurance": "25-30%",
                    "zone_3_tempo": "10-15%",
                    "zone_4_threshold": "5%",
                    "zone_5_vo2max": "0%",
                    "zone_6_sprint": "0%",
                    "note": "Threshold sets introduced. Building aerobic engine."
                ]
            case .two:
                return [
                    "zone_0_recovery": "10%",
                    "zone_1_aerobic_base": "40-45%",
                    "zone_2_aerobic_endurance": "25-30%",
                    "zone_3_tempo": "15%",
                    "zone_4_threshold": "5-10%",
                    "zone_5_vo2max": "0-5%",
                    "zone_6_sprint": "0%",
                    "note": "CSS pace sets introduced. Regular threshold work."
                ]
            case .three:
                return [
                    "zone_0_recovery": "10%",
                    "zone_1_aerobic_base": "35-40%",
                    "zone_2_aerobic_endurance": "25-30%",
                    "zone_3_tempo": "15-20%",
                    "zone_4_threshold": "10%",
                    "zone_5_vo2max": "5%",
                    "zone_6_sprint": "0-3%",
                    "note": "Race-pace work enters. Preparing for Gold group."
                ]
            default:
                return [
                    "zone_0_recovery": "10%",
                    "zone_1_aerobic_base": "40-45%",
                    "zone_2_aerobic_endurance": "25-30%",
                    "zone_3_tempo": "10-15%",
                    "zone_4_threshold": "5-10%",
                    "zone_5_vo2max": "0-5%",
                    "zone_6_sprint": "0%"
                ]
            }
        case .gold:
            return [
                "zone_0_recovery": "10%",
                "zone_1_aerobic_base": "35-40%",
                "zone_2_aerobic_endurance": "25-30%",
                "zone_3_tempo": "15-20%",
                "zone_4_threshold": "5-10%",
                "zone_5_vo2max": "0-5%",
                "zone_6_sprint": "0-3%",
                "note": "Full training spectrum available. Systematic threshold introduction."
            ]
        case .senior:
            return [
                "zone_0_recovery": "10%",
                "zone_1_aerobic_base": "25-30%",
                "zone_2_aerobic_endurance": "25-30%",
                "zone_3_tempo": "15-20%",
                "zone_4_threshold": "10-15%",
                "zone_5_vo2max": "5-10%",
                "zone_6_sprint": "3-5%",
                "note": "Significant high-intensity work. Event-specific training."
            ]
        case .national:
            return [
                "zone_0_recovery": "10%",
                "zone_1_aerobic_base": "15-20%",
                "zone_2_aerobic_endurance": "20-25%",
                "zone_3_tempo": "15-20%",
                "zone_4_threshold": "15-20%",
                "zone_5_vo2max": "10-15%",
                "zone_6_sprint": "5-10%",
                "note": "Elite training. Still 55-65% in Zones 0-2. Periodized intensity."
            ]
        }
    }

    func trainingFocusForTier(tier: TrainingTier, subTier: SubTier) -> [String] {
        switch tier {
        case .preCompetitive:
            return [
                "60-70%: Stroke technique drills (all four strokes introduced)",
                "15-20%: Starts and turns (basic dive, elementary flip turn)",
                "10-15%: Games, relays, fun activities",
                "0-5%: Timed swimming (sprint games only)"
            ]
        case .bronze:
            return [
                "40-50%: Stroke technique refinement (all four strokes)",
                "20-25%: Aerobic base building (distance at easy pace)",
                "15-20%: Starts, turns, underwater skills",
                "10-15%: Introduction to interval training",
                "0-5%: Sprint/race-pace (brief activities only)"
            ]
        case .silver:
            return [
                "30-35%: Stroke technique refinement (stroke-specific drills)",
                "30-35%: Aerobic base and endurance (longer sets, building volume)",
                "15-20%: Threshold introduction (CSS pace work)",
                "10-15%: Starts, turns, race strategy",
                "5-10%: Sprint work and race-pace activities"
            ]
        case .gold:
            return [
                "25-30%: Stroke-specific technique (form at higher volume)",
                "30-35%: Aerobic base and endurance (building capacity)",
                "15-20%: Threshold training (CSS work, pace clock intervals)",
                "10-15%: Race-pace work and sprint development",
                "10%: Starts, turns, underwaters, race strategy"
            ]
        case .senior:
            return [
                "20-25%: Stroke technique (fine-tuning at race pace)",
                "25-30%: Aerobic endurance (maintaining base)",
                "20-25%: Threshold and race-pace work",
                "10-15%: VO2max and lactate tolerance",
                "10%: Sprint work, starts, turns, race strategy"
            ]
        case .national:
            return [
                "15-20%: Technique fine-tuning (video analysis)",
                "20-25%: Aerobic maintenance",
                "20-25%: Threshold and race-pace (event-specific)",
                "15-20%: VO2max and lactate tolerance",
                "10-15%: Sprint and speed development",
                "10%: Starts, turns, race strategy, mental skills"
            ]
        }
    }

    func fullLevelName(tier: TrainingTier, subTier: SubTier) -> String {
        if tier.hasSubTiers && subTier != .none {
            return "\(tier.displayName) \(subTier.displayName)"
        }
        return tier.displayName
    }
}
