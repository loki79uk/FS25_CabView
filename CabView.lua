CabView = {}

CabView.modName = g_currentModName
CabView.specName = ("spec_%s.cabView"):format(g_currentModName)

function CabView.prerequisitesPresent(specializations)
	return SpecializationUtil.hasSpecialization(Enterable, specializations)
end

function CabView.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", CabView)
	SpecializationUtil.registerEventListener(vehicleType, "onEnterVehicle", CabView)
	SpecializationUtil.registerEventListener(vehicleType, "onLeaveVehicle", CabView)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", CabView)
end

function CabView:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient then
		local spec = self[CabView.specName]
		self:clearActionEventsTable(spec.actionEvents)

		if isActiveForInputIgnoreSelection then
			-- print("*** " .. self:getFullName() .. " ***")
			local actionEventId --(actionEventsTable, inputAction, target, callback, triggerUp, triggerDown, triggerAlways, startActive, callbackState, customIconName)
			_, actionEventId = self:addActionEvent(spec.actionEvents, "CABVIEW_LEAN_FORWARD", self, CabView.KeyDown_LeanForward, true, true, false, true, true, nil )
			g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_LOW)
			g_inputBinding:setActionEventTextVisibility(actionEventId, false)
			_, actionEventId = InputBinding.registerActionEvent(g_inputBinding, 'CABVIEW_LEAN_FORWARD', self, CabView.KeyDown_LeanForward, true, true, false, true)
			g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_LOW)
			g_inputBinding:setActionEventTextVisibility(actionEventId, false)
			
			_, actionEventId = self:addActionEvent(spec.actionEvents, "CABVIEW_LEAN_TOGGLE", self, CabView.KeyDown_LeanToggle, true, true, false, true, true, nil )
			g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_LOW)
			g_inputBinding:setActionEventTextVisibility(actionEventId, false)
			_, actionEventId = InputBinding.registerActionEvent(g_inputBinding, 'CABVIEW_LEAN_TOGGLE', self, CabView.KeyDown_LeanToggle, true, true, false, true)
			g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_LOW)
			g_inputBinding:setActionEventTextVisibility(actionEventId, false)
		end
	end
end

function CabView:onLoad(savegame)
	local spec = self[CabView.specName]
	spec.vehicleId	= self.rootNode
	
	--RESTRICT LEANING OUT OF BACK WINDOW FOR THESE VEHICLES
	if self.typeDesc == 'car' or
	self.typeDesc == 'truck' or
	self.typeName == 'carFillable' or
	self.typeName == 'addOtherVehiclesHere' then
		-- print("Leaning RESTRICTED")
		spec.restrictLean = true
	else
		spec.restrictLean = false
	end
	
	-- FIND INDOOR CAMERA:
	spec.indoorCameraNode = nil
	if self.spec_enterable ~= nil then
		for index, cameraBase in pairs(self.spec_enterable.cameras) do
			if cameraBase.isInside then
				spec.indoorCameraNode = cameraBase.cameraNode or cameraBase.cameraPositionNode
				
				spec.originalRotX = cameraBase.origRotX
				spec.originalRotY = cameraBase.origRotY%(2*math.pi)
				spec.originalRotZ = cameraBase.origRotZ
				spec.rotationOffset = spec.originalRotY - math.pi
				
				local settingsFovY = g_gameSettings:getValue("fovY")	
				if cameraBase.fovY ~= nil and cameraBase.fovY ~= settingsFovY then
					cameraBase.fovYBackup = nil
					setFovY(cameraBase.cameraNode, settingsFovY)
					-- print(self:getFullName())
					-- print("Set camera fov to " .. tostring(math.deg(settingsFovY)))
				end
				
			end
		end
	end
end

function CabView:onEnterVehicle(isControlling, playerStyle, farmId)
	if isControlling then
		local spec = self[CabView.specName]
		spec.resetView = true
		spec.leanButtonPressed = false
		spec.lean = 0
	end
end

function CabView:onLeaveVehicle(isControlling, playerStyle, farmId)
	-- print("LEAVING VEHICLE")
	local spec = self[CabView.specName]
	spec.leanButtonPressed = false
	spec.lean = 0
end

function CabView:KeyDown_LeanForward(actionName, inputValue)
	-- print("LEAN")
	local spec = self[CabView.specName]
	if spec then
		if inputValue == 1 then
			-- print("lean forward")
			spec.leanButtonPressed = true
		else
			-- print("lean backward")
			spec.leanButtonPressed = false
		end
	end
end

function CabView:KeyDown_LeanToggle(actionName, inputValue)
	-- print("LEAN TOGGLE")
	local spec = self[CabView.specName]
	if spec then
		if inputValue == 1 then
			spec.leanButtonPressed = not spec.leanButtonPressed
		end
	end
end


function CabView:vehicleCameraUpdate(superFunc, dt)

	-- CATCH AND ATTEMPT TO FIX THIS OCCASSIONAL ERROR
	if self.rotX==nil or self.rotY==nil then
		-- print("CABVIEW: Catch Error...")
		self.rotX = self.origRotX
		self.rotY = self.origRotY
	end

	-- RETURN NORMAL FUNCTION WHEN CAB VIEW IS NOT INSTALLED
	local spec = self.vehicle[CabView.specName]
	if not spec then
		return superFunc(self, dt)
	end

	-- DISABLE CABVIEW FOR UNIVERSAL PASSENGER (PASSENGERS ONLY)
	if self.vehicle.spec_universalPassenger ~= nil then
		if g_universalPassenger.currentPassengerVehicle ~= nil then
			if self.vehicle == g_universalPassenger.currentPassengerVehicle then
				-- print("Universal Passenger")
				return superFunc(self, dt)
			end
		end
	end
	
	-- RESET VIEW IF REQUIRED
	if self.isInside and spec.resetView then
		-- print("RESET VIEW")
		self.rotX = spec.originalRotX
		self.rotY = spec.originalRotY
		self.rotZ = spec.originalRotZ
		spec.resetView = false
	end

    local target = self.zoomTarget
    if self.zoomLimitedTarget >= 0 then
        target = math.min(self.zoomLimitedTarget, self.zoomTarget)
    end
    self.zoom = target + ( math.pow(0.99579, dt) * (self.zoom - target) )
	
    if self.lastInputValues.upDown ~= 0 then
        local value = self.lastInputValues.upDown * g_gameSettings:getValue(GameSettings.SETTING.CAMERA_SENSITIVITY)
        self.lastInputValues.upDown = 0
        value = g_gameSettings:getValue("invertYLook") and -value or value
        if self.isRotatable then
            if self.isActivated and not g_gui:getIsGuiVisible() then
                if self.limitRotXDelta > 0.001 then
                    self.rotX = math.min(self.rotX - value, self.rotX)
                elseif self.limitRotXDelta < -0.001 then
                    self.rotX = math.max(self.rotX - value, self.rotX)
                else
                    self.rotX = self.rotX - value
                end
                if self.limit then
                    self.rotX = math.min(self.rotMaxX, math.max(self.rotMinX, self.rotX))
                end
            end
        end
    end
    if self.lastInputValues.leftRight ~= 0 then
        local value = self.lastInputValues.leftRight * g_gameSettings:getValue(GameSettings.SETTING.CAMERA_SENSITIVITY)
        self.lastInputValues.leftRight = 0
        if self.isRotatable then
            if self.isActivated and not g_gui:getIsGuiVisible() then
				self.rotY = self.rotY - value
				if self.isInside then
					-- LIMIT ROTATION to +/- 180 degrees [+5%]
					local minRot = -0.1 * math.pi+spec.rotationOffset
					local maxRot =  2.1 * math.pi+spec.rotationOffset
					self.rotY = math.clamp(self.rotY, minRot, maxRot)
				end
            end
        end
    end
    --
    if g_gameSettings:getValue("isHeadTrackingEnabled") and isHeadTrackingAvailable() and self.allowHeadTracking and self.headTrackingNode ~= nil then
        local tx,ty,tz = getHeadTrackingTranslation()
        local pitch,yaw,roll = getHeadTrackingRotation()
        if pitch ~= nil then
            local camParent = getParent(self.cameraNode)
            local ctx, cty, ctz, crx, cry, crz = nil
            if camParent ~= 0 then
                ctx, cty, ctz = localToLocal(self.headTrackingNode, camParent, tx, ty, tz);
                crx, cry, crz = localRotationToLocal(self.headTrackingNode, camParent, pitch,yaw,roll);
            else
                ctx, cty, ctz = localToWorld(self.headTrackingNode, tx, ty, tz);
                crx, cry, crz = localRotationToWorld(self.headTrackingNode, pitch,yaw,roll);
            end
            setRotation(self.cameraNode, crx, cry, crz)
            setTranslation(self.cameraNode, ctx, cty, ctz)
        end
    else
        self:updateRotateNodeRotation()
        if self.limit then
            -- adjust rotation to avoid clipping with terrain
            if self.isRotatable and ((self.useWorldXZRotation == nil and g_gameSettings:getValue("useWorldCamera")) or self.useWorldXZRotation) then
                local numIterations = 4
                for i=1, numIterations do
                    local transX, transY, transZ = self.transDirX*self.zoom, self.transDirY*self.zoom, self.transDirZ*self.zoom
                    local x,y,z = localToWorld(getParent(self.cameraPositionNode), transX, transY, transZ)
                    local terrainHeight = DensityMapHeightUtil.getHeightAtWorldPos(x,0,z)
                    local minHeight = terrainHeight + 0.9
                    if y < minHeight then
                        local h = math.sin(self.rotX)*self.zoom
                        local h2 = h-(minHeight-y)
                        self.rotX = math.asin(math.clamp(h2/self.zoom, -1, 1))
                        self:updateRotateNodeRotation()
                    else
                        break
                    end
                end
            end
            -- adjust zoom to avoid collision with objects
            if self.allowTranslation then
                self.limitRotXDelta = 0
                local hasCollision, collisionDistance, nx,ny,nz, normalDotDir = self:getCollisionDistance()
                if hasCollision then
                    local distOffset = 0.1
                    if normalDotDir ~= nil then
                        local absNormalDotDir = math.abs(normalDotDir)
                        distOffset = MathUtil.lerp(1.2, 0.1, absNormalDotDir*absNormalDotDir*(3-2*absNormalDotDir))
                    end
                    collisionDistance = math.max(collisionDistance-distOffset, 0.01)
                    self.disableCollisionTime = g_currentMission.time+400
                    self.zoomLimitedTarget = collisionDistance
                    if collisionDistance < self.zoom then
                        self.zoom = collisionDistance
                    end
                    if self.isRotatable and nx ~= nil and collisionDistance < self.transMin then
                        local _,lny,_ = worldDirectionToLocal(self.rotateNode, nx,ny,nz)
                        if lny > 0.5 then
                            self.limitRotXDelta = 1
                        elseif lny < -0.5 then
                            self.limitRotXDelta = -1
                        end
                    end
                else
                    if self.disableCollisionTime <= g_currentMission.time then
                        self.zoomLimitedTarget = -1
                    end
                end
            end
        end
        self.transX, self.transY, self.transZ = self.transDirX*self.zoom, self.transDirY*self.zoom, self.transDirZ*self.zoom
		if self.isInside then
			spec.isInsideCamera = true
			local limit = 0.4
			local totalSide = 0
			local totalForward = 0
			-- shift camera direction angle to range from -pi to +pi (instead of 0 to 2pi)
			local angle = math.clamp(self.rotY-(math.pi+spec.rotationOffset), -math.pi, math.pi)

			-- INCREASE/DECREASE LEANING based on control inputs
			if spec.leanButtonPressed then
				if spec.lean < limit then
					spec.lean = spec.lean + dt/1000
				end
			else
				if spec.lean > 0 then
					spec.lean = spec.lean - dt/1000
				end
			end
			
			if math.abs(angle) <= math.pi/2 then
			-- ADD LEANING FORWARD in the direction player is looking
				-- print("LOOK FORWARD/SIDE")
				if angle>0 then
					totalSide = math.sin(angle)*spec.lean
				end
				if angle<0 then
					totalSide = math.sin(angle)*spec.lean
				end
				totalForward =  math.cos(angle)*spec.lean
			else
			-- ADD AUTOMATIC LEANING if looking more than 90 degrees left or right
				-- print("LOOK BACK")
				local autoLean = 0
				if angle>math.pi/2 then
					-- print("LEAN LEFT")
					autoLean = (angle-math.pi/2)/(2*math.pi)
					totalSide = autoLean + math.sin(angle)*spec.lean
				end
				if angle<-math.pi/2 then
					-- print("LEAN RIGHT")
					autoLean = (angle+math.pi/2)/(2*math.pi)
					totalSide = autoLean + math.sin(angle)*spec.lean
				end
				if spec.restrictLean then
					totalForward = 0
				else
					totalForward = math.cos(angle)*spec.lean/2
				end
			end
			
			if totalSide~=0 or totalForward~=0 then
			-- ROTATE NEW TRANSLATIONS BACK INTO ORIGINAL COORDINATE FRAME
				local x,y,z = worldDirectionToLocal(getParent(self.cameraPositionNode), self.transX, self.transY, self.transZ)
				self.transX = self.transX + totalSide*math.cos(-spec.rotationOffset) - totalForward*math.sin(-spec.rotationOffset)
				self.transZ = self.transZ + totalSide*math.sin(-spec.rotationOffset) + totalForward*math.cos(-spec.rotationOffset)
			end
		else
			spec.isInsideCamera = false
			spec.leanButtonPressed = false
			spec.lean = 0
		end
        setTranslation(self.cameraPositionNode, self.transX, self.transY, self.transZ)
        if self.positionSmoothingParameter > 0 then
            local interpDt = g_physicsDt
            if self.vehicle.spec_rideable ~= nil then
                interpDt = self.vehicle.spec_rideable.interpolationDt
            end
            if g_server == nil then
                -- on clients, we interpolate the vehicles with dt, thus we need to use the same for camera interpolation
                interpDt = dt
            end
            if interpDt > 0 then
                local xlook,ylook,zlook = getWorldTranslation(self.rotateNode)
                local lookAtPos = self.lookAtPosition
                local lookAtLastPos = self.lookAtLastTargetPosition
                lookAtPos[1],lookAtPos[2],lookAtPos[3] = self:getSmoothed(self.lookAtSmoothingParameter, lookAtPos[1],lookAtPos[2],lookAtPos[3], xlook,ylook,zlook, lookAtLastPos[1],lookAtLastPos[2],lookAtLastPos[3], interpDt)
                lookAtLastPos[1],lookAtLastPos[2],lookAtLastPos[3] = xlook,ylook,zlook
                local x,y,z = getWorldTranslation(self.cameraPositionNode)
                local pos = self.position
                local lastPos = self.lastTargetPosition
                pos[1],pos[2],pos[3] = self:getSmoothed(self.positionSmoothingParameter, pos[1],pos[2],pos[3], x,y,z, lastPos[1],lastPos[2],lastPos[3], interpDt)
                lastPos[1],lastPos[2],lastPos[3] = x,y,z
				local upx, upy, upz = localDirectionToWorld(self.rotateNode, self:getTiltDirectionOffset(), 1, 0)
				local up = self.upVector
				local lastUp = self.lastUpVector
				up[1], up[2], up[3] = self:getSmoothed(self.positionSmoothingParameter, up[1], up[2], up[3], upx, upy, upz, lastUp[1], lastUp[2], lastUp[3], interpDt)
				lastUp[1],lastUp[2],lastUp[3] = upx,upy,upz
                self:setSeparateCameraPose()
            end
        end
    end
end

-- print("  Loaded Mod: 'CabView'")
VehicleCamera.update = Utils.overwrittenFunction(VehicleCamera.update, CabView.vehicleCameraUpdate)