# --- NEW ENDPOINTS FOR iOS INTEGRATION ---

@app.post("/state/outfit")
async def update_outfit(
    request: Request,
    api_key: str = Security(verify_api_key)
):
    """Sync outfit changes from iOS app"""
    try:
        data = await request.json()
        state = WorldManager.load_json(WorldManager.STATE_FILE)
        
        state["her"]["current_outfit"] = {
            "description": data.get("outfit_description", ""),
            "style": data.get("style", "casual"),
            "changed_at": data.get("timestamp", time.time()),
            "reason": data.get("change_reason", "unknown")
        }
        
        WorldManager.save_state(state)
        logger.info(f"👗 Outfit updated: {data.get('outfit_description', '')[:50]}")
        
        return {"status": "success"}
    except Exception as e:
        logger.error(f"Outfit update error: {e}")
        raise HTTPException(500, str(e))


@app.post("/state/interaction")
async def record_interaction(
    request: Request,
    api_key: str = Security(verify_api_key)
):
    """Record physical interaction from iOS app"""
    try:
        data = await request.json()
        state = WorldManager.load_json(WorldManager.STATE_FILE)
        
        # We use 'emotional_meaning' as the unique key for interaction type
        meaning = data.get("emotional_meaning", "physical_touch")
        
        interaction = {
            "type": "touch",
            "part": data.get("part"),         # e.g. "Nose", "Lips"
            "gesture": data.get("gesture"),   # e.g. "Tap", "Slide"
            "intensity": data.get("intensity"),
            "emotional_meaning": meaning,
            "timestamp": data.get("timestamp", time.time())
        }
        
        # Add to interaction history
        if "interaction_history" not in state["her"]:
            state["her"]["interaction_history"] = []
        
        state["her"]["interaction_history"].append(interaction)
        
        # Keep only last 50 interactions
        state["her"]["interaction_history"] = state["her"]["interaction_history"][-50:]
        
        # Update intimacy/bonding metrics
        if "bonding_score" not in state["her"]:
            state["her"]["bonding_score"] = 0.5
        
        # Exact mapping to your supported touch gestures
        touch_bonding = {
            "intimate_finger_kiss": 0.05,    # Mouth + Tap
            "sensual_shy_touch": 0.04,       # Neck + Slide
            "affectionate_nuzzle": 0.03,     # Cheeks + Slide
            "mischievous_ear_stroke": 0.03,  # Ears + Slide
            "ticklish_play": 0.02,           # Ears + Tap
            "cute_boop": 0.02,               # Nose + Tap
            "playful_hair_tugging": 0.02,    # Hair + Pull
            "gentle_pat": 0.02,              # Hair + Tap
            "attention_seeking": 0.01,       # Shoulders + Tap
            "playful_tease_ouch": 0.01,      # Cheeks + Pinch
            "playful_annoyance": 0.00,       # Nose + Long Press (Neutral/Fun)
            "physical_touch": 0.01           # Fallback
        }
        
        # Calculate bonus based on the specific meaning
        bonus = touch_bonding.get(meaning, 0.01)
        
        # Apply intensity multiplier (Intense touches count slightly more)
        intensity_mult = 1.0
        if data.get("intensity") == 3: intensity_mult = 1.2
        elif data.get("intensity") == 1: intensity_mult = 0.8
        
        state["her"]["bonding_score"] = min(1.0, state["her"]["bonding_score"] + (bonus * intensity_mult))
        
        WorldManager.save_state(state)
        logger.info(f"💕 Interaction: {meaning} on {data.get('part')} (Bonding: {state['her']['bonding_score']:.3f})")
        
        return {"status": "success", "bonding_score": state["her"]["bonding_score"]}
    except Exception as e:
        logger.error(f"Interaction record error: {e}")
        raise HTTPException(500, str(e))


@app.post("/state/call")
async def update_call_state(
    request: Request,
    api_key: str = Security(verify_api_key)
):
    """Track call events from iOS app"""
    try:
        data = await request.json()
        state = WorldManager.load_json(WorldManager.STATE_FILE)
        
        event = data.get("event")
        call_type = data.get("type", "voice")
        
        if event == "call_started":
            state["her"]["in_call"] = True
            state["her"]["call_type"] = call_type
            state["her"]["call_start"] = data.get("timestamp", time.time())
            state["her"]["status"] = "on_call"
            logger.info(f"📞 Call started: {call_type}")
            
        elif event == "call_ended":
            duration = data.get("duration", 0)
            state["her"]["in_call"] = False
            state["her"]["call_type"] = None
            state["her"]["last_call_duration"] = duration
            state["her"]["status"] = "chilling"
            
            # Save call to memory
            MemoryManager.save(
                f"Had a {call_type} call with boyfriend for {int(duration/60)} minutes",
                context_chain_id="call_history"
            )
            logger.info(f"📞 Call ended: {int(duration)}s")
        
        WorldManager.save_state(state)
        return {"status": "success"}
    except Exception as e:
        logger.error(f"Call state error: {e}")
        raise HTTPException(500, str(e))


@app.get("/state/wind")
async def get_wind_state(api_key: str = Security(verify_api_key)):
    """Get wind state for current location"""
    state = WorldManager.load_json(WorldManager.STATE_FILE)
    world = WorldManager.load_json(WorldManager.WORLD_FILE)
    
    location_id = state["her"]["location"]
    location_data = world["locations"].get(location_id, {})
    
    # Check if outdoors
    outdoor_locations = ["balcony", "rooftop", "park", "beach", "mountain", "street", "flower_spot"]
    is_outdoor = location_id in outdoor_locations or location_data.get("is_outdoor", False)
    
    if not is_outdoor:
        return {
            "speed": 0.0,
            "direction": [1, 0],
            "gustiness": 0.0,
            "is_outdoor": False
        }
    
    # Base wind by location
    wind_profiles = {
        "beach": {"speed": 0.5, "gustiness": 0.4},
        "mountain": {"speed": 0.7, "gustiness": 0.6},
        "rooftop": {"speed": 0.4, "gustiness": 0.3},
        "park": {"speed": 0.2, "gustiness": 0.2},
        "default": {"speed": 0.15, "gustiness": 0.15}
    }
    
    profile = wind_profiles.get(location_id, wind_profiles["default"])
    
    return {
        "speed": profile["speed"],
        "direction": [0.8, 0.2],  # Could vary by time/weather
        "gustiness": profile["gustiness"],
        "is_outdoor": True,
        "location": location_id
    }