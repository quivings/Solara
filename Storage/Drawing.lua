local env = getgenv and getgenv() or _G
local cloneref = cloneref or function(v) return v end
local clonefunction = clonefunction or function(v) return v end

-- // Variables
local TextService = cloneref(game:GetService("TextService"))
local HttpService = cloneref(game:GetService("HttpService"))

local HttpGet = clonefunction(game.HttpGet)
local GetTextBoundsAsync = clonefunction(TextService.GetTextBoundsAsync)

local math = {
	atan2 = clonefunction(math.atan2),
	clamp = clonefunction(math.clamp),
	max = clonefunction(math.max),
	min = clonefunction(math.min),
	pi = math.pi,
	huge = math.huge
}

local string = {
	format = clonefunction(string.format),
	sub = clonefunction(string.sub)
}

local UDim2 = {
	new = clonefunction(UDim2.new),
	fromOffset = clonefunction(UDim2.fromOffset),
	fromScale = clonefunction(UDim2.fromScale)
}

local Vector2 = {
	new = clonefunction(Vector2.new),
	zero = Vector2.zero
}

local Color3 = {
	new = clonefunction(Color3.new),
}

-- // Drawing
local Drawing = {}

Drawing.__CLASSES = {}
Drawing.__OBJECT_CACHE = {}
Drawing.__IMAGE_CACHE = {}

Drawing.Font = {
	Count = 0,
	Fonts = {},
	Enums = {}
}

function Drawing.new(class)
	if not Drawing.__CLASSES[class] then
		error(`Invalid argument #1, expected a valid drawing type`, 2)
	end

	return Drawing.__CLASSES[class].new()
end

function Drawing.Font.new(FontName, FontData)

	local FontID = Drawing.Font.Count
	local FontObject

	Drawing.Font.Count += 1
	Drawing.Font.Fonts[FontName] = FontID

	if string.sub(FontData, 1, 11) == "rbxasset://" then
		FontObject = Font.new(FontData, Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	else
		local TempPath = HttpService:GenerateGUID(false)

		if not isfile(FontData) then
			writefile(`DrawingFontCache/{FontName}.ttf`, crypt.base64.decode(FontData))
			FontData = `DrawingFontCache/{FontName}.ttf`
		end

		writefile(TempPath, HttpService:JSONEncode({
			["name"] = FontName,
			["faces"] = {
				{
					["name"] = "Regular",
					["weight"] = 100,
					["style"] = "normal",
					["assetId"] = getcustomasset(FontData)
				}
			}
		}))

		FontObject = Font.new(getcustomasset(TempPath), Enum.FontWeight.Regular, Enum.FontStyle.Normal)

		delfile(TempPath)
	end

	if not FontObject then
		error("Internal Error while creating new font.", 2)
	end

	Drawing.__TEXT_BOUND_PARAMS.Text = "Text"
	Drawing.__TEXT_BOUND_PARAMS.Size = 12
	Drawing.__TEXT_BOUND_PARAMS.Font = FontObject
	Drawing.__TEXT_BOUND_PARAMS.Width = math.huge

	GetTextBoundsAsync(TextService, Drawing.__TEXT_BOUND_PARAMS) -- Preload/Cache font for GetTextBoundsAsync to avoid yielding across metamethods -- REMOVED as its erroring "temp read failed"

	Drawing.Font.Enums[FontID] = FontObject

	return FontObject
end

function Drawing.CreateInstance(class, properties, children)
	local object = Instance.new(class)

	for property, value in properties or {} do
		object[property] = value
	end

	for idx, child in children or {} do
		child.Parent = object
	end

	return object
end

function Drawing.ClearCache()
	for idx, object in Drawing.__OBJECT_CACHE do
		if rawget(object, "__OBJECT_EXISTS") then
			object:Remove()
		end
	end
end

function Drawing.UpdatePosition(object, from, to, thickness)
	local center = (from + to) / 2
	local offset = to - from

	object.Position = UDim2.fromOffset(center.X, center.Y)
	object.Size = UDim2.fromOffset(offset.Magnitude, thickness)
	object.Rotation = math.atan2(offset.Y, offset.X) * 180 / math.pi
end

Drawing.__ROOT = Drawing.CreateInstance("ScreenGui", {
	IgnoreGuiInset = true,
	DisplayOrder = 10,
	Name = HttpService:GenerateGUID(false),
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = gethui()
})

Drawing.__TEXT_BOUND_PARAMS = Drawing.CreateInstance("GetTextBoundsParams", { Width = math.huge })

--#region Line
local Line = {}

Drawing.__CLASSES["Line"] = Line

function Line.new()
	local LineObject = setmetatable({
		__OBJECT_EXISTS = true,
		__PROPERTIES = {
			Color = Color3.new(0, 0, 0),
			From = Vector2.zero,
			To = Vector2.zero,
			Thickness = 1,
			Transparency = 1,
			ZIndex = 0,
			Visible = false
		},
		__OBJECT = Drawing.CreateInstance("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(0, 0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(0, 0, 0, 0),
			BorderSizePixel = 0,
			ZIndex = 0,
			Visible = false,
			Parent = Drawing.__ROOT
		})
	}, Line)

	table.insert(Drawing.__OBJECT_CACHE, LineObject)

	return LineObject
end

function Line:__index(property)
	local value = self.__PROPERTIES[property]

	if value ~= nil then
		return value
	end

	return Line[property]
end

function Line:__newindex(property, value)
	if not self.__OBJECT_EXISTS then
		return error("Attempt to modify drawing that no longer exists!", 2)
	end

	local Properties = self.__PROPERTIES

	Properties[property] = value

	if property == "Color" then
		self.__OBJECT.BackgroundColor3 = value
	elseif property == "From" then
		Drawing.UpdatePosition(self.__OBJECT, Properties.From, Properties.To, Properties.Thickness)
	elseif property == "To" then
		Drawing.UpdatePosition(self.__OBJECT, Properties.From, Properties.To, Properties.Thickness)
	elseif property == "Thickness" then
		self.__OBJECT.Size = UDim2.fromOffset(self.__OBJECT.AbsoluteSize.X, math.max(value, 1))
	elseif property == "Transparency" then
		self.__OBJECT.Transparency = math.clamp(1 - value, 0, 1)
	elseif property == "Visible" then
		self.__OBJECT.Visible = value
	elseif property == "ZIndex" then
		self.__OBJECT.ZIndex = value
	end
end

function Line:__iter()
	return next, self.__PROPERTIES
end

function Line:__tostring()
	return "Drawing"
end

function Line:Remove()
	self.__OBJECT_EXISTS = false
	self.__OBJECT.Destroy(self.__OBJECT)
	table.remove(Drawing.__OBJECT_CACHE, table.find(Drawing.__OBJECT_CACHE, self))
end

function Line:Destroy()
	self:Remove()
end
--#endregion

--#region Circle
local Circle = {}

Drawing.__CLASSES["Circle"] = Circle

function Circle.new()
	local CircleObject = setmetatable({
		__OBJECT_EXISTS = true,
		__PROPERTIES = {
			Color = Color3.new(0, 0, 0),
			Position = Vector2.new(0, 0),
			NumSides = 0,
			Radius = 0,
			Thickness = 1,
			Transparency = 1,
			ZIndex = 0,
			Filled = false,
			Visible = false
		},
		__OBJECT = Drawing.CreateInstance("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(0, 0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(0, 0, 0, 0),
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
			ZIndex = 0,
			Visible = false,
			Parent = Drawing.__ROOT
		}, {
			Drawing.CreateInstance("UICorner", {
				Name = "_CORNER",
				CornerRadius = UDim.new(1, 0)
			}),
			Drawing.CreateInstance("UIStroke", {
				Name = "_STROKE",
				Color = Color3.new(0, 0, 0),
				Thickness = 1
			})
		}),
	}, Circle)

	table.insert(Drawing.__OBJECT_CACHE, CircleObject)

	return CircleObject
end

function Circle:__index(property)
	local value = self.__PROPERTIES[property]

	if value ~= nil then
		return value
	end

	return Circle[property]
end

function Circle:__newindex(property, value)
	if not self.__OBJECT_EXISTS then
		return error("Attempt to modify drawing that no longer exists!", 2)
	end

	local Properties = self.__PROPERTIES

	Properties[property] = value

	if property == "Color" then
		self.__OBJECT.BackgroundColor3 = value
		self.__OBJECT._STROKE.Color = value
	elseif property == "Filled" then
		self.__OBJECT.BackgroundTransparency = value and 1 - Properties.Transparency or 1
	elseif property == "Position" then
		self.__OBJECT.Position = UDim2.fromOffset(value.X, value.Y)
	elseif property == "Radius" then
		self:__UPDATE_RADIUS()
	elseif property == "Thickness" then
		self:__UPDATE_RADIUS()
	elseif property == "Transparency" then
		self.__OBJECT._STROKE.Transparency = math.clamp(1 - value, 0, 1)
		self.__OBJECT.Transparency = Properties.Filled and math.clamp(1 - value, 0, 1) or self.__OBJECT.Transparency
	elseif property == "Visible" then
		self.__OBJECT.Visible = value
	elseif property == "ZIndex" then
		self.__OBJECT.ZIndex = value
	end
end

function Circle:__iter()
	return next, self.__PROPERTIES
end

function Circle:__tostring()
	return "Drawing"
end

function Circle:__UPDATE_RADIUS()
	local diameter = (self.__PROPERTIES.Radius * 2) - (self.__PROPERTIES.Thickness * 2)
	self.__OBJECT.Size = UDim2.fromOffset(diameter, diameter)
end

function Circle:Remove()
	self.__OBJECT_EXISTS = false
	self.__OBJECT.Destroy(self.__OBJECT)
	table.remove(Drawing.__OBJECT_CACHE, table.find(Drawing.__OBJECT_CACHE, self))
end

function Circle:Destroy()
	self:Remove()
end
--#endregion

--#region Text
local Text = {}

Drawing.__CLASSES["Text"] = Text

function Text.new()
	local TextObject = setmetatable({
		__OBJECT_EXISTS = true,
		__PROPERTIES = {
			Color = Color3.new(1, 1, 1),
			OutlineColor = Color3.new(0, 0, 0),
			Position = Vector2.new(0, 0),
			TextBounds = Vector2.new(0, 0),
			Text = "",
			Font = Drawing.Font.Enums[2],
			Size = 13,
			Transparency = 1,
			ZIndex = 0,
			Center = false,
			Outline = false,
			Visible = false
		},
		__OBJECT = Drawing.CreateInstance("TextLabel", {
			TextColor3 = Color3.new(1, 1, 1),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(0, 0, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			FontFace = Drawing.Font.Enums[1],
			TextSize = 12,
			BackgroundTransparency = 1,
			ZIndex = 0,
			Visible = false,
			Parent = Drawing.__ROOT
		}, {
			Drawing.CreateInstance("UIStroke", {
				Name = "_STROKE",
				Color = Color3.new(0, 0, 0),
				LineJoinMode = Enum.LineJoinMode.Miter,
				Enabled = false,
				Thickness = 1
			})
		})
	}, Text)

	table.insert(Drawing.__OBJECT_CACHE, TextObject)

	return TextObject
end

function Text:__index(property)
	local value = self.__PROPERTIES[property]

	if value ~= nil then
		return value
	end

	return Text[property]
end

function Text:__newindex(property, value)
	if not self.__OBJECT_EXISTS then
		return error("Attempt to modify drawing that no longer exists!", 2)
	end

	if value == "TextBounds" then
		error("Attempt to modify read-only property", 2)
	end

	local Properties = self.__PROPERTIES

	Properties[property] = value

	if property == "Color" then
		self.__OBJECT.TextColor3 = value
	elseif property == "Position" then
		self.__OBJECT.Position = UDim2.fromOffset(value.X, value.Y)
	elseif property == "Size" then
		self.__OBJECT.TextSize = value - 1
		self:_UPDATE_TEXT_BOUNDS()
	elseif property == "Text" then
		self.__OBJECT.Text = value
		self:_UPDATE_TEXT_BOUNDS()
	elseif property == "Font" then
		if type(value) == "string" then
			value = Drawing.Font.Enums[Drawing.Font.Fonts[value]]
		elseif type(value) == "number" then
			value = Drawing.Font.Enums[value]
		end

		Properties.Font = value

		self.__OBJECT.FontFace = value
		self:_UPDATE_TEXT_BOUNDS()
	elseif property == "Outline" then
		self.__OBJECT._STROKE.Enabled = value
	elseif property == "OutlineColor" then
		self.__OBJECT._STROKE.Color = value
	elseif property == "Center" then
		self.__OBJECT.TextXAlignment = value and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
	elseif property == "Transparency" then
		self.__OBJECT.Transparency = math.clamp(1 - value, 0, 1)
	elseif property == "Visible" then
		self.__OBJECT.Visible = value
	elseif property == "ZIndex" then
		self.__OBJECT.ZIndex = value
	end
end

function Text:__iter()
	return next, self.__PROPERTIES
end

function Text:__tostring()
	return "Drawing"
end

function Text:_UPDATE_TEXT_BOUNDS()
	local Properties = self.__PROPERTIES

	Drawing.__TEXT_BOUND_PARAMS.Text = Properties.Text
	Drawing.__TEXT_BOUND_PARAMS.Size = Properties.Size - 1
	Drawing.__TEXT_BOUND_PARAMS.Font = Properties.Font
	Drawing.__TEXT_BOUND_PARAMS.Width = math.huge

	Properties.TextBounds = GetTextBoundsAsync(TextService, Drawing.__TEXT_BOUND_PARAMS)
end

function Text:Remove()
	self.__OBJECT_EXISTS = false
	self.__OBJECT.Destroy(self.__OBJECT)
	table.remove(Drawing.__OBJECT_CACHE, table.find(Drawing.__OBJECT_CACHE, self))
end

function Text:Destroy()
	self:Remove()
end
--#endregion

--#region Square
local Square = {}

Drawing.__CLASSES["Square"] = Square

function Square.new()
	local SquareObject = setmetatable({
		__OBJECT_EXISTS = true,
		__PROPERTIES = {
			Color = Color3.new(0, 0, 0),
			Position = Vector2.new(0, 0),
			Size = Vector2.new(0, 0),
			Rounding = 0,
			Thickness = 0,
			Transparency = 1,
			ZIndex = 0,
			Filled = false,
			Visible = false
		},
		__OBJECT = Drawing.CreateInstance("Frame", {
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(0, 0, 0, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 0,
			Visible = false,
			Parent = Drawing.__ROOT
		}, {
			Drawing.CreateInstance("UIStroke", {
				Name = "_STROKE",
				Color = Color3.new(0, 0, 0),
				LineJoinMode = Enum.LineJoinMode.Miter,
				Thickness = 1
			}),
			Drawing.CreateInstance("UICorner", {
				Name = "_CORNER",
				CornerRadius = UDim.new(0, 0)
			})
		})
	}, Square)

	table.insert(Drawing.__OBJECT_CACHE, SquareObject)

	return SquareObject
end

function Square:__index(property)
	local value = self.__PROPERTIES[property]

	if value ~= nil then
		return value
	end

	return Square[property]
end

function Square:__newindex(property, value)
	if not self.__OBJECT_EXISTS then
		return error("Attempt to modify drawing that no longer exists!", 2)
	end

	local Properties = self.__PROPERTIES

	Properties[property] = value

	if property == "Color" then
		self.__OBJECT.BackgroundColor3 = value
		self.__OBJECT._STROKE.Color = value
	elseif property == "Position" then
		self:__UPDATE_SCALE()
	elseif property == "Size" then
		self:__UPDATE_SCALE()
	elseif property == "Thickness" then
		self.__OBJECT._STROKE.Thickness = value
		self.__OBJECT._STROKE.Enabled = not Properties.Filled
		self:__UPDATE_SCALE()
	elseif property == "Rounding" then
		self.__OBJECT._CORNER.CornerRadius = UDim.new(0, value)
	elseif property == "Filled" then
		self.__OBJECT._STROKE.Enabled = not value
		self.__OBJECT.BackgroundTransparency = value and 1 - Properties.Transparency or 1
	elseif property == "Transparency" then
		self.__OBJECT.Transparency = math.clamp(1 - value, 0, 1)
	elseif property == "Visible" then
		self.__OBJECT.Visible = value
	elseif property == "ZIndex" then
		self.__OBJECT.ZIndex = value
	end
end

function Square:__iter()
	return next, self.__PROPERTIES
end

function Square:__tostring()
	return "Drawing"
end

function Square:__UPDATE_SCALE()
	local Properties = self.__PROPERTIES

	self.__OBJECT.Position = UDim2.fromOffset(Properties.Position.X + Properties.Thickness, Properties.Position.Y + Properties.Thickness)
	self.__OBJECT.Size = UDim2.fromOffset(Properties.Size.X - Properties.Thickness * 2, Properties.Size.Y - Properties.Thickness * 2)
end

function Square:Remove()
	self.__OBJECT_EXISTS = false
	self.__OBJECT.Destroy(self.__OBJECT)
	table.remove(Drawing.__OBJECT_CACHE, table.find(Drawing.__OBJECT_CACHE, self))
end

function Square:Destroy()
	self:Remove()
end
--#endregion

--#region Image
local Image = {}

Drawing.__CLASSES["Image"] = Image

function Image.new()
	local ImageObject = setmetatable({
		__OBJECT_EXISTS = true,
		__PROPERTIES = {
			Color = Color3.new(0, 0, 0),
			Position = Vector2.new(0, 0),
			Size = Vector2.new(0, 0),
			Data = "",
			Uri = "",
			Thickness = 0,
			Transparency = 1,
			ZIndex = 0,
			Filled = false,
			Visible = false
		},
		__OBJECT = Drawing.CreateInstance("ImageLabel", {
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(0, 0, 0, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			Image = "",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 0,
			Visible = false,
			Parent = Drawing.__ROOT
		}, {
			Drawing.CreateInstance("UICorner", {
				Name = "_CORNER",
				CornerRadius = UDim.new(0, 0)
			})
		})
	}, Image)

	table.insert(Drawing.__OBJECT_CACHE, ImageObject)

	return ImageObject
end

function Image:__index(property)
	local value = self.__PROPERTIES[property]

	if value ~= nil then
		return value
	end

	return Image[property]
end

function Image:__newindex(property, value)
	if not self.__OBJECT_EXISTS then
		return error("Attempt to modify drawing that no longer exists!", 2)
	end

	local Properties = self.__PROPERTIES

	Properties[property] = value

	if property == "Data" then
		self:__SET_IMAGE(value)
	elseif property == "Uri" then
		self:__SET_IMAGE(value, true)
	elseif property == "Rounding" then
		self.__OBJECT._CORNER.CornerRadius = UDim.new(0, value)
	elseif property == "Color" then
		self.__OBJECT.ImageColor3 = value
	elseif property == "Position" then
		self.__OBJECT.Position = UDim2.fromOffset(value.X, value.Y)
	elseif property == "Size" then
		self.__OBJECT.Size = UDim2.fromOffset(value.X, value.Y)
	elseif property == "Transparency" then
		self.__OBJECT.ImageTransparency = math.clamp(1 - value, 0, 1)
	elseif property == "Visible" then
		self.__OBJECT.Visible = value
	elseif property == "ZIndex" then
		self.__OBJECT.ZIndex = value
	end
end

function Image:__iter()
	return next, self.__PROPERTIES
end

function Image:__tostring()
	return "Drawing"
end

function Image:__SET_IMAGE(data, isUri)
	task.spawn(function()
		if isUri then
			data = HttpGet(game, data, true)
		end

		if not Drawing.__IMAGE_CACHE[data] then
			local TempPath = HttpService:GenerateGUID(false)

			writefile(TempPath, data)
			Drawing.__IMAGE_CACHE[data] = getcustomasset(TempPath)
			delfile(TempPath)
		end

		self.__PROPERTIES.Data = Drawing.__IMAGE_CACHE[data]
		self.__OBJECT.Image = Drawing.__IMAGE_CACHE[data]
	end)
end

function Image:Remove()
	self.__OBJECT_EXISTS = false
	self.__OBJECT.Destroy(self.__OBJECT)
	table.remove(Drawing.__OBJECT_CACHE, table.find(Drawing.__OBJECT_CACHE, self))
end

function Image:Destroy()
	self:Remove()
end
--#endregion

--#region Triangle
local Triangle = {}

Drawing.__CLASSES["Triangle"] = Triangle

function Triangle.new()
	local TriangleObject = setmetatable({
		__OBJECT_EXISTS = true,
		__PROPERTIES = {
			Color = Color3.new(0, 0, 0),
			PointA = Vector2.new(0, 0),
			PointB = Vector2.new(0, 0),
			PointC = Vector2.new(0, 0),
			Thickness = 1,
			Transparency = 1,
			ZIndex = 0,
			Filled = false,
			Visible = false
		},
		__OBJECT = Drawing.CreateInstance("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			ZIndex = 0,
			Visible = false,
			Parent = Drawing.__ROOT
		}, {
			Drawing.CreateInstance("Frame", {
				Name = "_A",
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(0, 0, 0, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BorderSizePixel = 0,
				ZIndex = 0
			}),
			Drawing.CreateInstance("Frame", {
				Name = "_B",
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(0, 0, 0, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BorderSizePixel = 0,
				ZIndex = 0
			}),
			Drawing.CreateInstance("Frame", {
				Name = "_C",
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(0, 0, 0, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BorderSizePixel = 0,
				ZIndex = 0
			})
		})
	}, Triangle)

	table.insert(Drawing.__OBJECT_CACHE, TriangleObject)

	return TriangleObject
end

function Triangle:__index(property)
	local value = self.__PROPERTIES[property]

	if value ~= nil then
		return value
	end

	return Triangle[property]
end

function Triangle:__newindex(property, value)
	if not self.__OBJECT_EXISTS then
		return error("Attempt to modify drawing that no longer exists!", 2)
	end

	local Properties, Object = self.__PROPERTIES, self.__OBJECT

	Properties[property] = value

	if property == "Color" then
		Object._A.BackgroundColor3 = value
		Object._B.BackgroundColor3 = value
		Object._C.BackgroundColor3 = value
	elseif property == "Transparency" then
		Object._A.BackgroundTransparency = 1 - value
		Object._B.BackgroundTransparency = 1 - value
		Object._C.BackgroundTransparency = 1 - value
	elseif property == "Thickness" then
		Object._A.BackgroundColor3 = UDim2.fromOffset(Object._A.AbsoluteSize.X, math.max(value, 1));
		Object._B.BackgroundColor3 = UDim2.fromOffset(Object._B.AbsoluteSize.X, math.max(value, 1));
		Object._C.BackgroundColor3 = UDim2.fromOffset(Object._C.AbsoluteSize.X, math.max(value, 1));
	elseif property == "PointA" then
		self:__UPDATE_VERTICIES({
			{ Object._A, Properties.PointA, Properties.PointB },
			{ Object._C, Properties.PointC, Properties.PointA }
		})
	elseif property == "PointB" then
		self:__UPDATE_VERTICIES({
			{ Object._A, Properties.PointA, Properties.PointB },
			{ Object._B, Properties.PointB, Properties.PointC }
		})
	elseif property == "PointC" then
		self:__UPDATE_VERTICIES({
			{ Object._B, Properties.PointB, Properties.PointC },
			{ Object._C, Properties.PointC, Properties.PointA }
		})
	elseif property == "Visible" then
		Object.Visible = value
	elseif property == "ZIndex" then
		Object.ZIndex = value
	end
end

function Triangle:__iter()
	return next, self.__PROPERTIES
end

function Triangle:__tostring()
	return "Drawing"
end

function Triangle:__UPDATE_VERTICIES(verticies)
	local thickness = self.__PROPERTIES.Thickness

	for idx, verticy in verticies do
		Drawing.UpdatePosition(verticy[1], verticy[2], verticy[3], thickness)
	end
end

function Triangle:Remove()
	self.__OBJECT_EXISTS = false
	self.__OBJECT.Destroy(self.__OBJECT)
	table.remove(Drawing.__OBJECT_CACHE, table.find(Drawing.__OBJECT_CACHE, self))
end

function Triangle:Destroy()
	self:Remove()
end
--#endregion

--#region Quad
local Quad = {}

Drawing.__CLASSES["Quad"] = Quad

function Quad.new()
	local QuadObject = setmetatable({
		__OBJECT_EXISTS = true,
		__PROPERTIES = {
			Color = Color3.new(0, 0, 0),
			PointA = Vector2.new(0, 0),
			PointB = Vector2.new(0, 0),
			PointC = Vector2.new(0, 0),
			PointD = Vector2.new(0, 0),
			Thickness = 1,
			Transparency = 1,
			ZIndex = 0,
			Filled = false,
			Visible = false
		},
		__OBJECT = Drawing.CreateInstance("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			ZIndex = 0,
			Visible = false,
			Parent = Drawing.__ROOT
		}, {
			Drawing.CreateInstance("Frame", {
				Name = "_A",
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(0, 0, 0, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BorderSizePixel = 0,
				ZIndex = 0
			}),
			Drawing.CreateInstance("Frame", {
				Name = "_B",
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(0, 0, 0, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BorderSizePixel = 0,
				ZIndex = 0
			}),
			Drawing.CreateInstance("Frame", {
				Name = "_C",
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(0, 0, 0, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BorderSizePixel = 0,
				ZIndex = 0
			}),
			Drawing.CreateInstance("Frame", {
				Name = "_D",
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(0, 0, 0, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BorderSizePixel = 0,
				ZIndex = 0
			})
		})
	}, Quad)

	table.insert(Drawing.__OBJECT_CACHE, QuadObject)

	return QuadObject
end

function Quad:__index(property)
	local value = self.__PROPERTIES[property]

	if value ~= nil then
		return value
	end

	return Quad[property]
end

function Quad:__newindex(property, value)
	if not self.__OBJECT_EXISTS then
		return error("Attempt to modify drawing that no longer exists!", 2)
	end

	local Properties, Object = self.__PROPERTIES, self.__OBJECT

	Properties[property] = value

	if property == "Color" then
		Object._A.BackgroundColor3 = value
		Object._B.BackgroundColor3 = value
		Object._C.BackgroundColor3 = value
		Object._D.BackgroundColor3 = value
	elseif property == "Transparency" then
		Object._A.BackgroundTransparency = 1 - value
		Object._B.BackgroundTransparency = 1 - value
		Object._C.BackgroundTransparency = 1 - value
		Object._D.BackgroundTransparency = 1 - value
	elseif property == "Thickness" then
		Object._A.BackgroundColor3 = UDim2.fromOffset(Object._A.AbsoluteSize.X, math.max(value, 1));
		Object._B.BackgroundColor3 = UDim2.fromOffset(Object._B.AbsoluteSize.X, math.max(value, 1));
		Object._C.BackgroundColor3 = UDim2.fromOffset(Object._C.AbsoluteSize.X, math.max(value, 1));
		Object._D.BackgroundColor3 = UDim2.fromOffset(Object._D.AbsoluteSize.X, math.max(value, 1));
	elseif property == "PointA" then
		self:__UPDATE_VERTICIES({
			{ Object._A, Properties.PointA, Properties.PointB },
			{ Object._D, Properties.PointD, Properties.PointA }
		})
	elseif property == "PointB" then
		self:__UPDATE_VERTICIES({
			{ Object._A, Properties.PointA, Properties.PointB },
			{ Object._B, Properties.PointB, Properties.PointC }
		})
	elseif property == "PointC" then
		self:__UPDATE_VERTICIES({
			{ Object._B, Properties.PointB, Properties.PointC },
			{ Object._C, Properties.PointC, Properties.PointD }
		})
	elseif property == "PointD" then
		self:__UPDATE_VERTICIES({
			{ Object._C, Properties.PointC, Properties.PointD },
			{ Object._D, Properties.PointD, Properties.PointA }
		})
	elseif property == "Visible" then
		Object.Visible = value
	elseif property == "ZIndex" then
		Object.ZIndex = value
	end
end

function Quad:__iter()
	return next, self.__PROPERTIES
end

function Quad:__tostring()
	return "Drawing"
end

function Quad:__UPDATE_VERTICIES(verticies)
	local thickness = self.__PROPERTIES.Thickness

	for idx, verticy in verticies do
		Drawing.UpdatePosition(verticy[1], verticy[2], verticy[3], thickness)
	end
end

function Quad:Remove()
	self.__OBJECT_EXISTS = false
	self.__OBJECT.Destroy(self.__OBJECT)
	table.remove(Drawing.__OBJECT_CACHE, table.find(Drawing.__OBJECT_CACHE, self))
end

function Quad:Destroy()
	self:Remove()
end
--#endregion

if not isfolder("DrawingFontCache") then
	makefolder("DrawingFontCache")
end

Drawing.Font.new("UI", "rbxasset://fonts/families/Arial.json")
Drawing.Font.new("System", "rbxasset://fonts/families/HighwayGothic.json")
--Drawing.Font.new("Plex", "AAEAAAAMAIAAAwBAT1MvMojrdJAAAAFIAAAATmNtYXACEiN1AAADoAAAAVJjdnQgAAAAAAAABPwAAAACZ2x5ZhKviVYAAAcEAACSgGhlYWTXkWbTAAAAzAAAADZoaGVhCEIBwwAAAQQAAAAkaG10eIoAfoAAAAGYAAACBmxvY2GMc7DYAAAFAAAAAgRtYXhwAa4A2gAAASgAAAAgbmFtZSVZu5YAAJmEAAABnnBvc3SmrIPvAACbJAAABdJwcmVwaQIBEgAABPQAAAAIAAEAAAABAAA8VenVXw889QADCAAAAAAAt2d3hAAAAAC9kqbXAAD+gAOABQAAAAADAAIAAAAAAAAAAQAABMD+QAAAA4AAAAAAA4AAAQAAAAAAAAAAAAAAAAAAAAIAAQAAAQEAkAAkAAAAAAACAAgAQAAKAAAAdgAIAAAAAAAAA4ABkAAFAAACvAKKAAAAjwK8AooAAAHFADICAAAAAAAECQAAAAAAAAAAAAAAAAAAAAAAAAAAAABBbHRzAEAAACCsCAAAAAAABQABgAAAA4AAAAOAA4ADgAOAA4ADgAOAA4ADgAOAA4ADgAOAA4ADgAOAA4ADgAOAA4ADgAOAA4ADgAOAA4ADgAOAA4ADgAOAA4ADgAOAAYABAAAAAIAAAACAAYABAAEAAIAAgACAAIABAACAAIAAgACAAIAAgACAAIAAgACAAIABgACAAAAAgACAAIAAAACAAIAAgACAAIAAgACAAIABAACAAIAAgAAAAIAAgACAAIAAgACAAAAAgAAAAAAAgAAAAIABAACAAQAAgAAAAQAAgACAAIAAgACAAIAAgACAAQAAgACAAQAAAACAAIAAgACAAIAAgAEAAIAAgAAAAIAAgACAAIABgACAAAADgACAA4ABAACAAQAAgACAAIAAgACAAIAAgAAAA4AAgAOAA4ABgAEAAQAAgACAAIAAAACAAAAAgACAAAADgACAAAADgAGAAIAAgAAAAAABgACAAQAAAACAAIAAgAOAAAAAAACAAIAAgACAAYAAAACAAQABgACAAIAAgACAAIAAAACAAIAAgACAAIAAgACAAAAAgACAAIAAgACAAQABAAEAAQAAAACAAIAAgACAAIAAgACAAIAAgACAAIAAgAAAAIAAAACAAIAAgACAAIAAgAAAAIAAgACAAIAAgAEAAQABAAEAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAAAAAAAMAAAAAAAAAHAABAAAAAABMAAMAAQAAABwABAAwAAAACAAIAAIAAAB/AP8grP//AAAAAACBIKz//wABAAHf1QABAAAAAAAAAAAAAAEGAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACxAAGNuAH/hQAAAAAAAADGAMYAxgDGAMYAxgDGAMYAxgDGAMYAxgDGAMYAxgDGAMYAxgDGAMYAxgDGAMYAxgDGAMYAxgDGAMYAxgDGAMYAxgDGAPQBHAGeAhQCiAL8AxQDWAOcA94EFAQyBFAEYgSiBRYFZgW8BhIGdAbWBzgHfgfsCE4IbAiWCNAJEAlKCYgKFgqACwQLVgvIDC4MggzqDV4NpA3qDlAOlg8oD7AQEhB0EOARUhG2EgQSbhLEE0wTrBP2FFgUrhTqFUAVgBWmFbgWEhZ+FsYXNBeOF+AYVhi6GO4ZNhmWGdQaSBqcGvAbXBvIHAQcTByWHOodKh2SHdIeQB6OHuAfJB92H6YfpiAQIBAgLiCKILIgyCEUIXQhmCHuImIihiMMIwwjgCOAI4AjmCOwI9gkACRKJGgkkCSuJQYlYCWCJfgl+CZYJqomqibYJ0AnmigKKGgoqCkOKSApuCn4KjYqYCpgKwIrKiteK6wr5iwgLDQsmi0oLVwteC2qLeguJi6mLyYvti/0MF4wyDE+MbQyHjKeMx4zgjPuNFw0zjU6NYY11DYmNnI25jd2N9g4OjimORI5dDmuOi46mjsGO3w76Dw6PJY9Ij2GPew+Vj7GPyo/mkASQGpA0EE2QaJCCEJAQnpCuELwQ2JDzEQqRIpE7kVYRbZF4kZURrRHFEd6R9pIVEjGSUAAJAAA/oADgAUAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwBTAFcAWwBfAGMAZwBrAG8AcwB3AHsAfwCDAIcAiwCPAAARNTMVMTUzFTE1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUxNTMVMTUzFTE1MxWAgICAgICA/ICAAoCA/ICAAoCA/ICAAoCA/ICAAoCA/ICAAoCA/ICAAoCA/ICAAoCA/ICAAoCA/ICAAoCA/ICAAoCA/ICAAoCA/ICAgICAgICABICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAABwGAAAACAAQAAAMABwALAA8AEwAXABsAAAE1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFQM1MxUBgICAgICAgICAgICAgIADgICAgICAgICAgICAgICAgICA/wCAgAAGAQADAAKABIAAAwAHAAsADwATABcAAAE1MxUzNTMVBTUzFTM1MxUFNTMVMzUzFQEAgICA/oCAgID+gICAgAQAgICAgICAgICAgICAgIAAABgAAAAAA4AEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwBLAE8AUwBXAFsAXwAAATUzFTM1MxUFNTMVMzUzFQU1MxUxNTMVMTUzFTE1MxUxNTMVMTUzFQU1MxUzNTMVBTUzFTM1MxUFNTMVMTUzFTE1MxUxNTMVMTUzFTE1MxUFNTMVMzUzFQU1MxUzNTMVAYCAgID+gICAgP2AgICAgICA/YCAgID+gICAgP2AgICAgICA/YCAgID+gICAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAFQCA/4ADAAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwBTAAABNTMVBTUzFTE1MxUxNTMVMTUzFQU1MxUzNTMVBTUzFTM1MxUFNTMVMTUzFTE1MxUFNTMVMzUzFQU1MxUzNTMVBTUzFTE1MxUxNTMVMTUzFQU1MxUBgID/AICAgID9gICAgP6AgICA/wCAgID/AICAgP6AgICA/YCAgICA/wCAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAAUAAAAAAOABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAAATNTMVITUzFQU1MxUzNTMVMzUzFQU1MxUzNTMVMzUzFQU1MxUzNTMVBzUzFTM1MxUFNTMVMzUzFTM1MxUFNTMVMzUzFTM1MxUFNTMVITUzFYCAAYCA/QCAgICAgP2AgICAgID+AICAgICAgID+AICAgICA/YCAgICAgP0AgAGAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAAFACAAAADgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwAAATUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUhNTMVBTUzFSE1MxUzNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTM1MxUBAICA/oCAAQCA/gCAAQCA/oCAgAEAgP0AgAEAgICA/QCAAYCA/YCAAYCA/gCAgICAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAMBgAMAAgAEgAADAAcACwAAATUzFQc1MxUHNTMVAYCAgICAgAQAgICAgICAgIAAAAsBAP8AAoAEgAADAAcACwAPABMAFwAbAB8AIwAnACsAAAE1MxUFNTMVBzUzFQU1MxUHNTMVBzUzFQc1MxUHNTMdATUzFQc1Mx0BNTMVAgCA/wCAgID/AICAgICAgICAgICAgIAEAICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAALAQD/AAKABIAAAwAHAAsADwATABcAGwAfACMAJwArAAABNTMdATUzFQc1Mx0BNTMVBzUzFQc1MxUHNTMVBzUzFQU1MxUHNTMVBTUzFQEAgICAgICAgICAgICAgP8AgICA/wCABACAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAACwCAAIADAAMAAAMABwALAA8AEwAXABsAHwAjACcAKwAAATUzFQU1MxUzNTMVMzUzFQU1MxUxNTMVMTUzFQU1MxUzNTMVMzUzFQU1MxUBgID+gICAgICA/gCAgID+AICAgICA/oCAAoCAgICAgICAgICAgICAgICAgICAgICAgICAgAAACQCAAIADAAMAAAMABwALAA8AEwAXABsAHwAjAAABNTMVBzUzFQU1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUBgICAgP6AgICAgID+gICAgAKAgICAgICAgICAgICAgICAgICAgICAgAAABACA/wABgAEAAAMABwALAA8AACU1MxUHNTMVBzUzFQU1MxUBAICAgICA/wCAgICAgICAgICAgICAAAAABQCAAYADAAIAAAMABwALAA8AEwAAEzUzFTE1MxUxNTMVMTUzFTE1MxWAgICAgIABgICAgICAgICAgIAAAgEAAAABgAEAAAMABwAAJTUzFQc1MxUBAICAgICAgICAgAAACgCA/4ADAASAAAMABwALAA8AEwAXABsAHwAjACcAAAE1MxUHNTMVBTUzFQc1MxUFNTMVBzUzFQU1MxUHNTMVBTUzFQc1MxUCgICAgP8AgICA/wCAgID/AICAgP8AgICABACAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAUAIAAAAMABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAAABNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTM1MxUzNTMVBTUzFTM1MxUzNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFQEAgICA/gCAAYCA/YCAAYCA/YCAgICAgP2AgICAgID9gIABgID9gIABgID+AICAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAADgCAAAADAAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwAAATUzFQU1MxUxNTMVBTUzFTM1MxUHNTMVBzUzFQc1MxUHNTMVBTUzFTE1MxUxNTMVMTUzFTE1MxUBgID/AICA/oCAgICAgICAgICAgP6AgICAgIADgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAA8AgAAAAwAEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwAAATUzFTE1MxUxNTMVBTUzFSE1MxUHNTMVBTUzFQU1MxUFNTMVBTUzFQc1MxUxNTMVMTUzFTE1MxUxNTMVAQCAgID+AIABgICAgP8AgP8AgP8AgP8AgICAgICAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAPAIAAAAMABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAAAE1MxUxNTMVMTUzFQU1MxUhNTMVBzUzFQU1MxUxNTMdATUzFQc1MxUFNTMVITUzFQU1MxUxNTMVMTUzFQEAgICA/gCAAYCAgID+gICAgICA/YCAAYCA/gCAgIADgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAEQCAAAADgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwAAATUzFQU1MxUxNTMVBTUzFTM1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUCgID/AICA/oCAgID+AIABAID9gIABgID9gICAgICAgP8AgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAABIAgAAAAwAEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwAAEzUzFTE1MxUxNTMVMTUzFTE1MxUFNTMVBzUzFQc1MxUxNTMVMTUzFTE1Mx0BNTMVBzUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVgICAgICA/YCAgICAgICAgICAgP2AgAGAgP4AgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAARAIAAAAMABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAAABNTMVMTUzFQU1MxUFNTMVBzUzFTE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFQGAgID+gID/AICAgICAgP4AgAGAgP2AgAGAgP2AgAGAgP4AgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAADACAAAADAAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvAAATNTMVMTUzFTE1MxUxNTMVMTUzFQc1MxUFNTMVBzUzFQU1MxUHNTMVBTUzFQc1MxWAgICAgICAgP8AgICA/wCAgID/AICAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAATAIAAAAMABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwAAATUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFQEAgICA/gCAAYCA/YCAAYCA/gCAgID+AIABgID9gIABgID9gIABgID+AICAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAEQCAAAADAAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwAAATUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFQc1MxUFNTMVBTUzFTE1MxUBAICAgP4AgAGAgP2AgAGAgP2AgAGAgP4AgICAgICA/wCA/oCAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAQBgAAAAgADAAADAAcACwAPAAABNTMVBzUzFQM1MxUHNTMVAYCAgICAgICAAoCAgICAgP6AgICAgIAAAAYAgP8AAYADAAADAAcACwAPABMAFwAAATUzFQc1MxUDNTMVBzUzFQc1MxUFNTMVAQCAgICAgICAgID/AIACgICAgICA/oCAgICAgICAgICAgAAAAAoAAACAAwADAAADAAcACwAPABMAFwAbAB8AIwAnAAABNTMVMTUzFQU1MxUxNTMVBTUzFTE1Mx0BNTMVMTUzHQE1MxUxNTMVAgCAgP4AgID+AICAgICAgAKAgICAgICAgICAgICAgICAgICAgICAgICAAAAADACAAQADgAKAAAMABwALAA8AEwAXABsAHwAjACcAKwAvAAATNTMVMTUzFTE1MxUxNTMVMTUzFTE1MxUBNTMVMTUzFTE1MxUxNTMVMTUzFTE1MxWAgICAgICA/QCAgICAgIACAICAgICAgICAgICAgP8AgICAgICAgICAgICAAAAKAIAAgAOAAwAAAwAHAAsADwATABcAGwAfACMAJwAAEzUzFTE1Mx0BNTMVMTUzHQE1MxUxNTMVBTUzFTE1MxUFNTMVMTUzFYCAgICAgID+AICA/gCAgAKAgICAgICAgICAgICAgICAgICAgICAgICAAAAAAAoAgAAAAwAEAAADAAcACwAPABMAFwAbAB8AIwAnAAABNTMVMTUzFTE1MxUFNTMVITUzFQc1MxUFNTMVBTUzFQc1MxUDNTMVAQCAgID+AIABgICAgP8AgP8AgICAgIADgICAgICAgICAgICAgICAgICAgICAgICA/wCAgAAaAAAAAAOABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAFMAVwBbAF8AYwBnAAABNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVMTUzFTM1MxUFNTMVMzUzFTM1MxUzNTMVBTUzFTM1MxUzNTMVMzUzFQU1MxUhNTMVMTUzFTE1MxUFNTMdATUzFTE1MxUxNTMVMTUzFQEAgICA/gCAAYCA/QCAAQCAgICA/ICAgICAgICA/ICAgICAgICA/ICAAQCAgID9gICAgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAABIAgAAAA4AEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwAAATUzFTE1MxUFNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVAYCAgP8AgID+gIABAID+AIABAID+AICAgID9gIACAID9AIACAID9AIACAIADgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAAGACAAAADgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwBTAFcAWwBfAAATNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFTE1MxWAgICAgP4AgAGAgP2AgAGAgP2AgICAgID9gIACAID9AIACAID9AIACAID9AICAgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAADgCAAAADgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwAAATUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVBzUzFQc1MxUHNTMdATUzFSE1MxUFNTMVMTUzFTE1MxUBgICAgP4AgAGAgP0AgICAgICAgIABgID+AICAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAUAIAAAAOABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAAATNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFYCAgICA/gCAAYCA/YCAAgCA/QCAAgCA/QCAAgCA/QCAAgCA/QCAAYCA/YCAgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAATAIAAAAMABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwAAEzUzFTE1MxUxNTMVMTUzFTE1MxUFNTMVBzUzFQc1MxUxNTMVMTUzFTE1MxUFNTMVBzUzFQc1MxUHNTMVMTUzFTE1MxUxNTMVMTUzFYCAgICAgP2AgICAgICAgID+AICAgICAgICAgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAPAIAAAAMABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAABM1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUHNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUHNTMVBzUzFYCAgICAgP2AgICAgICAgID+AICAgICAgIADgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAASAIAAAAOABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcAAAE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFQc1MxUHNTMVITUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFQGAgICA/gCAAYCA/QCAgICAgAEAgICA/QCAAgCA/YCAAYCA/gCAgIADgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAAFACAAAADgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwAAEzUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxWAgAIAgP0AgAIAgP0AgAIAgP0AgICAgICA/QCAAgCA/QCAAgCA/QCAAgCA/QCAAgCAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAwBAAAAAoAEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAAATUzFTE1MxUxNTMVBTUzFQc1MxUHNTMVBzUzFQc1MxUHNTMVBTUzFTE1MxUxNTMVAQCAgID/AICAgICAgICAgICA/wCAgIADgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAADACAAAACgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvAAABNTMVMTUzFTE1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFQc1MxUFNTMVMTUzFTE1MxUBAICAgICAgICAgICAgICAgP4AgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAARAIAAAAOABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAAATNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMzUzFQU1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFYCAAgCA/QCAAYCA/YCAAQCA/gCAgID+gICAgP6AgAEAgP4AgAGAgP2AgAIAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAMAIAAAAMABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AABM1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFQc1MxUHNTMVMTUzFTE1MxUxNTMVMTUzFYCAgICAgICAgICAgICAgICAgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAABoAAAAAA4AEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwBLAE8AUwBXAFsAXwBjAGcAABE1MxUxNTMVITUzFTE1MxUFNTMVMTUzFSE1MxUxNTMVBTUzFTM1MxUzNTMVMzUzFQU1MxUzNTMVMzUzFTM1MxUFNTMVITUzFSE1MxUFNTMVITUzFSE1MxUFNTMVITUzFQU1MxUhNTMVgIABgICA/ICAgAGAgID8gICAgICAgID8gICAgICAgID8gIABAIABAID8gIABAIABAID8gIACgID8gIACgIADgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAYAIAAAAOABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAFMAVwBbAF8AABM1MxUxNTMVITUzFQU1MxUxNTMVITUzFQU1MxUzNTMVITUzFQU1MxUzNTMVITUzFQU1MxUhNTMVMzUzFQU1MxUhNTMVMzUzFQU1MxUhNTMVMTUzFQU1MxUhNTMVMTUzFYCAgAGAgP0AgIABgID9AICAgAEAgP0AgICAAQCA/QCAAQCAgID9AIABAICAgP0AgAGAgID9AIABgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAABAAgAAAA4AEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AAABNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVAYCAgP6AgAEAgP2AgAIAgP0AgAIAgP0AgAIAgP0AgAIAgP2AgAEAgP6AgIADgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAARAIAAAAMABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAAATNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFQU1MxUHNTMVBzUzFYCAgICA/gCAAYCA/YCAAYCA/YCAAYCA/YCAgICA/gCAgICAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAAEgCA/4ADgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAAABNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMzUzFQc1MxUBgICA/oCAAQCA/YCAAgCA/QCAAgCA/QCAAgCA/QCAAgCA/YCAAQCA/oCAgICAgIADgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAFACAAAADgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwAAEzUzFTE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxWAgICAgP4AgAGAgP2AgAGAgP2AgAGAgP2AgICAgP4AgAEAgP4AgAGAgP2AgAIAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAEgCAAAADgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAAABNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMdATUzFTE1Mx0BNTMVMTUzHQE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUBAICAgID9gIACAID9AICAgICAgP0AgAIAgP2AgICAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAAOAAAAAAOABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3AAARNTMVMTUzFTE1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFYCAgICAgID+AICAgICAgICAgICAgIADgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAASAIAAAAOABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcAABM1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFYCAAgCA/QCAAgCA/QCAAgCA/QCAAgCA/QCAAgCA/QCAAgCA/QCAAgCA/YCAgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAA4AAAAAA4AEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAABE1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTM1MxUFNTMVMzUzFQU1MxUHNTMVgAKAgPyAgAKAgP0AgAGAgP2AgAGAgP4AgICA/oCAgID/AICAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAYAAAAAAOABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAFMAVwBbAF8AABE1MxUhNTMVBTUzFSE1MxUhNTMVBTUzFSE1MxUhNTMVBTUzFTM1MxUzNTMVMzUzFQU1MxUzNTMVMzUzFTM1MxUFNTMVMTUzFTM1MxUxNTMVBTUzFSE1MxUFNTMVITUzFYACgID8gIABAIABAID8gIABAIABAID8gICAgICAgID8gICAgICAgID9AICAgICA/YCAAYCA/YCAAYCAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAABAAgAAAA4AEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AAATNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFQU1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVgIACAID9AIACAID9gIABAID+gICA/wCAgP6AgAEAgP2AgAIAgP0AgAIAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAwAAAAAA4AEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAAETUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTM1MxUFNTMVBzUzFQc1MxUHNTMVgAKAgPyAgAKAgP0AgAGAgP4AgICA/wCAgICAgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAASAIAAAAOABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcAABM1MxUxNTMVMTUzFTE1MxUxNTMVMTUzFQc1MxUFNTMVBTUzFQU1MxUFNTMVBTUzFQc1MxUxNTMVMTUzFTE1MxUxNTMVMTUzFYCAgICAgICAgP8AgP8AgP8AgP8AgP8AgICAgICAgIADgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAADwEA/wACgASAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AAABNTMVMTUzFTE1MxUFNTMVBzUzFQc1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFQc1MxUHNTMVMTUzFTE1MxUBAICAgP6AgICAgICAgICAgICAgICAgICAgICABACAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAoAgP+AAwAEgAADAAcACwAPABMAFwAbAB8AIwAnAAATNTMVBzUzHQE1MxUHNTMdATUzFQc1Mx0BNTMVBzUzHQE1MxUHNTMVgICAgICAgICAgICAgICAgAQAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAA8BAP8AAoAEgAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwAAATUzFTE1MxUxNTMVBzUzFQc1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFQc1MxUHNTMVBTUzFTE1MxUxNTMVAQCAgICAgICAgICAgICAgICAgICAgID+gICAgAQAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAKAIABgAMABIAAAwAHAAsADwATABcAGwAfACMAJwAAATUzFQc1MxUFNTMVMzUzFQU1MxUzNTMVBTUzFSE1MxUFNTMVITUzFQGAgICA/wCAgID+gICAgP4AgAGAgP2AgAGAgAQAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAcAAP+AA4AAAAADAAcACwAPABMAFwAbAAAVNTMVMTUzFTE1MxUxNTMVMTUzFTE1MxUxNTMVgICAgICAgICAgICAgICAgICAgICAgAACAQADgAIABIAAAwAHAAABNTMdATUzFQEAgIAEAICAgICAAAAQAIAAAAMAAwAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwAAATUzFTE1MxUxNTMdATUzFQU1MxUxNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFQEAgICAgP4AgICAgP2AgAGAgP2AgAGAgP4AgICAgAKAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAATAIAAAAMABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwAAEzUzFQc1MxUHNTMVBzUzFTE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFYCAgICAgICAgICA/gCAAYCA/YCAAYCA/YCAAYCA/YCAAYCA/YCAgICABACAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAMAIAAAAMAAwAAAwAHAAsADwATABcAGwAfACMAJwArAC8AAAE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFQc1MxUHNTMVITUzFQU1MxUxNTMVMTUzFQEAgICA/gCAAYCA/YCAgICAgAGAgP4AgICAAoCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAATAIAAAAMABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwAAATUzFQc1MxUHNTMVBTUzFTE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFQKAgICAgID+AICAgID9gIABgID9gIABgID9gIABgID9gIABgID+AICAgIAEAICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAAEACAAAADAAMAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AAAE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFTE1MxUFNTMVBzUzFSE1MxUFNTMVMTUzFTE1MxUBAICAgP4AgAGAgP2AgICAgID9gICAgAGAgP4AgICAAoCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAADgCAAAADAASAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwAAATUzFTE1MxUxNTMVBTUzFQc1MxUFNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUHNTMVBzUzFQc1MxUBgICAgP4AgICA/wCAgICA/oCAgICAgICAgIAEAICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAAVAID+gAMAAwAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAFMAAAE1MxUxNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUHNTMVBzUzFQU1MxUxNTMVMTUzFQEAgICAgP2AgAGAgP2AgAGAgP2AgAGAgP2AgAGAgP4AgICAgICAgID+AICAgAKAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAABEAgAAAAwAEgAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMAABM1MxUHNTMVBzUzFQc1MxUxNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVgICAgICAgICAgID+AIABgID9gIABgID9gIABgID9gIABgID9gIABgIAEAICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAACAEAAAACAASAAAMABwALAA8AEwAXABsAHwAAATUzFQE1MxUxNTMVBzUzFQc1MxUHNTMVBzUzFQc1MxUBgID/AICAgICAgICAgICAgAQAgID+gICAgICAgICAgICAgICAgICAgIAAAAAMAID/AAKABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AAAE1MxUBNTMVMTUzFQc1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFQU1MxUxNTMVMTUzFQIAgP8AgICAgICAgICAgICAgID+AICAgAQAgID+gICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAQAIAAAAMABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwAAEzUzFQc1MxUHNTMVBzUzFSE1MxUFNTMVITUzFQU1MxUzNTMVBTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFYCAgICAgICAAYCA/YCAAQCA/gCAgID+gICAgP6AgAEAgP4AgAGAgAQAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAAKAQAAAAIABIAAAwAHAAsADwATABcAGwAfACMAJwAAATUzFTE1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFQEAgICAgICAgICAgICAgICAgICABACAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAFAAAAAADgAMAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwAAETUzFTE1MxUxNTMVMzUzFTE1MxUFNTMVITUzFSE1MxUFNTMVITUzFSE1MxUFNTMVITUzFSE1MxUFNTMVITUzFSE1MxUFNTMVITUzFSE1MxWAgICAgID9AIABAIABAID8gIABAIABAID8gIABAIABAID8gIABAIABAID8gIABAIABAIACgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAA4AgAAAAwADAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAABM1MxUxNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVgICAgID+AIABgID9gIABgID9gIABgID9gIABgID9gIABgIACgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAA4AgAAAAwADAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAAAE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVAQCAgID+AIABgID9gIABgID9gIABgID9gIABgID+AICAgAKAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAABMAgP6AAwADAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwBLAAATNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUHNTMVgICAgID+AIABgID9gIABgID9gIABgID9gIABgID9gICAgID+AICAgICAAoCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAABMAgP6AAwADAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwBLAAABNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUxNTMVBzUzFQc1MxUHNTMVAQCAgICA/YCAAYCA/YCAAYCA/YCAAYCA/YCAAYCA/gCAgICAgICAgICAAoCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAoAgAAAAwADAAADAAcACwAPABMAFwAbAB8AIwAnAAATNTMVMzUzFTE1MxUFNTMVMTUzFSE1MxUFNTMVBzUzFQc1MxUHNTMVgICAgID+AICAAQCA/YCAgICAgICAAoCAgICAgICAgICAgICAgICAgICAgICAgICAAA0AgAAAAwADAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzAAABNTMVMTUzFTE1MxUxNTMVBTUzHQE1MxUxNTMdATUzHQE1MxUFNTMVMTUzFTE1MxUxNTMVAQCAgICA/YCAgICAgP2AgICAgAKAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAA0BAAAAAwAEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzAAABNTMVBzUzFQc1MxUxNTMVMTUzFTE1MxUFNTMVBzUzFQc1MxUHNTMdATUzFTE1MxUxNTMVAQCAgICAgICAgP4AgICAgICAgICAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAOAIAAAAMAAwAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3AAATNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFYCAAYCA/YCAAYCA/YCAAYCA/YCAAYCA/YCAAYCA/gCAgICAAoCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAKAIAAAAMAAwAAAwAHAAsADwATABcAGwAfACMAJwAAEzUzFSE1MxUFNTMVITUzFQU1MxUzNTMVBTUzFTM1MxUFNTMVBzUzFYCAAYCA/YCAAYCA/gCAgID+gICAgP8AgICAAoCAgICAgICAgICAgICAgICAgICAgICAgICAAAAAABIAAAAAA4ADAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwAAETUzFSE1MxUFNTMVITUzFSE1MxUFNTMVITUzFSE1MxUFNTMVMzUzFTM1MxUzNTMVBTUzFTE1MxUzNTMVMTUzFQU1MxUhNTMVgAKAgPyAgAEAgAEAgPyAgAEAgAEAgPyAgICAgICAgP0AgICAgID9gIABgIACgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAKAIAAAAMAAwAAAwAHAAsADwATABcAGwAfACMAJwAAEzUzFSE1MxUFNTMVMzUzFQU1MxUHNTMVBTUzFTM1MxUFNTMVITUzFYCAAYCA/gCAgID/AICAgP8AgICA/gCAAYCAAoCAgICAgICAgICAgICAgICAgICAgICAgICAAAAAABMAgP6AAwADAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwBLAAATNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFQc1MxUHNTMVBTUzFTE1MxUxNTMVgIABgID9gIABgID9gIABgID9gIABgID9gIABgID+AICAgICAgICA/gCAgIACgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAOAIAAAAMAAwAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3AAATNTMVMTUzFTE1MxUxNTMVMTUzFQc1MxUFNTMVBTUzFQU1MxUFNTMVMTUzFTE1MxUxNTMVMTUzFYCAgICAgICA/wCA/wCA/wCA/wCAgICAgAKAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAOAID/AAMABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3AAABNTMVMTUzFQU1MxUHNTMVBzUzFQc1MxUFNTMVMTUzHQE1MxUHNTMVBzUzFQc1Mx0BNTMVMTUzFQIAgID+gICAgICAgID+gICAgICAgICAgICABACAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAsBgP8AAgAEgAADAAcACwAPABMAFwAbAB8AIwAnACsAAAE1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFQc1MxUHNTMVAYCAgICAgICAgICAgICAgICAgICAgIAEAICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAOAID/AAMABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3AAATNTMVMTUzHQE1MxUHNTMVBzUzFQc1Mx0BNTMVMTUzFQU1MxUHNTMVBzUzFQc1MxUFNTMVMTUzFYCAgICAgICAgICAgP6AgICAgICAgP6AgIAEAICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAAAgAAAGAA4ACgAADAAcACwAPABMAFwAbAB8AABM1MxUxNTMVMTUzFSE1MxUFNTMVITUzFTE1MxUxNTMVgICAgAEAgPyAgAEAgICAAgCAgICAgICAgICAgICAgICAgAAAABMAgAAAA4ADgAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwBLAAABNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUFNTMVBTUzFTE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVAYCAgID+AIABgID9AICAgID+gID/AICAgID+gIABgID+AICAgAMAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAABAEA/wACAAEAAAMABwALAA8AACU1MxUHNTMVBzUzFQU1MxUBgICAgICA/wCAgICAgICAgICAgICAAAAAEACA/wADAASAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AAAE1MxUxNTMVBTUzFQc1MxUFNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUHNTMVBzUzFQc1MxUHNTMVBTUzFTE1MxUCAICA/oCAgID/AICAgID+gICAgICAgICAgICA/oCAgAQAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAYBAP+AAoABAAADAAcACwAPABMAFwAAJTUzFTM1MxUFNTMVMzUzFQU1MxUzNTMVAQCAgID+gICAgP6AgICAgICAgICAgICAgICAgICAAAAAAwCAAAADAACAAAMABwALAAAzNTMVMzUzFTM1MxWAgICAgICAgICAgIAAAAANAIAAAAMABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwAAATUzFQc1MxUFNTMVMTUzFTE1MxUxNTMVMTUzFQU1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFQGAgICA/oCAgICAgP6AgICAgICAgICAgIAEAICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAABEAgAAAAwAEgAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMAAAE1MxUHNTMVBTUzFTE1MxUxNTMVMTUzFTE1MxUFNTMVBTUzFTE1MxUxNTMVMTUzFTE1MxUFNTMVBzUzFQc1MxUHNTMVAYCAgID+gICAgICA/oCA/oCAgICAgP6AgICAgICAgAQAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAAAUAgAMAAwAEgAADAAcACwAPABMAAAE1MxUFNTMVMzUzFQU1MxUhNTMVAYCA/wCAgID+AIABgIAEAICAgICAgICAgICAgAAAAA4AgAAAA4AEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAAAE1MxUFNTMVITUzFQU1MxUzNTMVBzUzFQU1MxUHNTMVMzUzFTM1MxUFNTMVITUzFTM1MxUFNTMVAgCA/gCAAQCA/gCAgICAgP8AgICAgICAgP0AgAEAgICA/QCAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAAVAIAAAAOABQAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAFMAAAE1MxUzNTMVBTUzFQU1MxUxNTMVMTUzFTE1MxUFNTMVITUzFQU1Mx0BNTMVMTUzHQE1MxUxNTMdATUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFQEAgICA/wCA/wCAgICA/YCAAgCA/QCAgICAgID9AIACAID9gICAgIAEgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAABQCAAIACAAMAAAMABwALAA8AEwAAATUzFQU1MxUFNTMdATUzHQE1MxUBgID/AID/AICAgAKAgICAgICAgICAgICAgIAAAAAAGAAAAAADgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwBTAFcAWwBfAAATNTMVMTUzFTM1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUzNTMVMTUzFTE1MxWAgICAgICA/ICAAQCA/gCAAQCA/gCAAQCAgID9AIABAID+AIABAID+AIABAID+gICAgICAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAABUAgAAAA4AFAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwBLAE8AUwAAATUzFTM1MxUFNTMVBTUzFTE1MxUxNTMVMTUzFTE1MxUxNTMVBzUzFQU1MxUFNTMVBTUzFQU1MxUFNTMVBzUzFTE1MxUxNTMVMTUzFTE1MxUxNTMVAQCAgID/AID+gICAgICAgICA/wCA/wCA/wCA/wCA/wCAgICAgICAgASAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAADAYADAAKABIAAAwAHAAsAAAE1MxUHNTMdATUzFQGAgICAgAQAgICAgICAgIAAAAADAQADAAIABIAAAwAHAAsAAAE1MxUHNTMVBTUzFQGAgICA/wCABACAgICAgICAgAAGAQADAAMABIAAAwAHAAsADwATABcAAAE1MxUzNTMVBTUzFTM1MxUFNTMVMzUzFQEAgICA/oCAgID/AICAgAQAgICAgICAgICAgICAgIAAAAYAgAMAAoAEgAADAAcACwAPABMAFwAAATUzFTM1MxUFNTMVMzUzFQU1MxUzNTMVAQCAgID+gICAgP4AgICABACAgICAgICAgICAgICAgAAADQCAAIADAAMAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMAAAE1MxUFNTMVMTUzFTE1MxUFNTMVMTUzFTE1MxUxNTMVMTUzFQU1MxUxNTMVMTUzFQU1MxUBgID/AICAgP4AgICAgID+AICAgP8AgAKAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAAAUAgAGAAwACAAADAAcACwAPABMAABM1MxUxNTMVMTUzFTE1MxUxNTMVgICAgICAAYCAgICAgICAgICAAAcAAAGAA4ACAAADAAcACwAPABMAFwAbAAARNTMVMTUzFTE1MxUxNTMVMTUzFTE1MxUxNTMVgICAgICAgAGAgICAgICAgICAgICAgIAAAAAABACAAwACgAQAAAMABwALAA8AAAE1MxUzNTMVBTUzFTM1MxUBAICAgP4AgICAA4CAgICAgICAgIAAAAAAEAAAAgADgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AABE1MxUxNTMVMTUzFTM1MxUxNTMVMTUzFQU1MxUhNTMVMTUzFTE1MxUFNTMVITUzFTM1MxUFNTMVITUzFTM1MxWAgICAgICA/QCAAQCAgID9AIABAICAgP0AgAEAgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAQAIAAAAMABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwAAATUzFTM1MxUFNTMVATUzFTE1MxUxNTMVMTUzFQU1Mx0BNTMVMTUzHQE1Mx0BNTMVBTUzFTE1MxUxNTMVMTUzFQEAgICA/wCA/wCAgICA/YCAgICAgP2AgICAgAQAgICAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAAFAIAAgAIAAwAAAwAHAAsADwATAAATNTMdATUzHQE1MxUFNTMVBTUzFYCAgID/AID/AIACgICAgICAgICAgICAgICAABUAAAAAA4ADAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwBLAE8AUwAAEzUzFTE1MxUzNTMVMTUzFQU1MxUhNTMVITUzFQU1MxUhNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFSE1MxUFNTMVMTUzFTM1MxUxNTMVgICAgICA/QCAAQCAAQCA/ICAAQCAgICA/ICAAQCA/gCAAQCAAQCA/QCAgICAgAKAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAAEQCAAAADAASAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwAAATUzFTM1MxUFNTMVATUzFTE1MxUxNTMVMTUzFTE1MxUHNTMVBTUzFQU1MxUFNTMVBTUzFTE1MxUxNTMVMTUzFTE1MxUBAICAgP8AgP6AgICAgICAgP8AgP8AgP8AgP8AgICAgIAEAICAgICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAADQAAAAADgASAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMAAAE1MxUzNTMVATUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTM1MxUFNTMVBzUzFQc1MxUBAICAgP2AgAKAgPyAgAKAgP0AgAGAgP4AgICA/wCAgICAgAQAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAAHAYAAAAIABAAAAwAHAAsADwATABcAGwAAATUzFQM1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFQGAgICAgICAgICAgICAgAOAgID/AICAgICAgICAgICAgICAgICAABIAgP+AAwADgAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwAAATUzFQU1MxUxNTMVMTUzFQU1MxUzNTMVMzUzFQU1MxUzNTMVBTUzFTM1MxUFNTMVMzUzFTM1MxUFNTMVMTUzFTE1MxUFNTMVAYCA/wCAgID+AICAgICA/YCAgID+gICAgP6AgICAgID+AICAgP8AgAMAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAAQAIAAAAMABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwAAATUzFTE1MxUFNTMVBzUzFQU1MxUxNTMVMTUzFTE1MxUFNTMVBzUzFQU1MxUHNTMVMTUzFTE1MxUxNTMVMTUzFQGAgID+gICAgP8AgICAgP6AgICA/wCAgICAgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAUAAAAAAOAA4AAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAAARNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFTE1MxUFNTMVITUzFYACgID9AICAgICA/YCAAYCA/YCAAYCA/YCAAYCA/YCAgICAgP0AgAKAgAMAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAABAAAAAAA4AEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AAARNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMzUzFQU1MxUFNTMVMTUzFTE1MxUxNTMVMTUzFQU1MxUHNTMVgAKAgPyAgAKAgP0AgAGAgP4AgICA/wCA/oCAgICAgP6AgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAACgGA/wACAASAAAMABwALAA8AEwAXABsAHwAjACcAAAE1MxUHNTMVBzUzFQc1MxUHNTMVAzUzFQc1MxUHNTMVBzUzFQc1MxUBgICAgICAgICAgICAgICAgICAgIAEAICAgICAgICAgICAgICA/wCAgICAgICAgICAgICAgAAAAAASAIAAAAMABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcAAAE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzHQE1MxUxNTMVBTUzFTM1MxUFNTMVMTUzHQE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFQEAgICA/gCAAYCA/YCAgID/AICAgP8AgICA/YCAAYCA/gCAgIAEAICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAACAQAEAAKABIAAAwAHAAABNTMVMzUzFQEAgICABACAgICAAAAcAAAAAAOABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAFMAVwBbAF8AYwBnAGsAbwAAEzUzFTE1MxUxNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVMTUzFTM1MxUFNTMVMzUzFSE1MxUFNTMVMzUzFSE1MxUFNTMVITUzFTE1MxUzNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUxNTMVMTUzFYCAgICAgP0AgAKAgPyAgAEAgICAgPyAgICAAYCA/ICAgIABgID8gIABAICAgID8gIACgID9AICAgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAACwCAAYACgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAAATUzFTE1Mx0BNTMVBTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUBAICAgP6AgICA/gCAAQCA/oCAgIADgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAKAIAAgAMAAwAAAwAHAAsADwATABcAGwAfACMAJwAAATUzFTM1MxUFNTMVMzUzFQU1MxUzNTMVBTUzFTM1MxUFNTMVMzUzFQGAgICA/gCAgID+AICAgP8AgICA/wCAgIACgICAgICAgICAgICAgICAgICAgICAgICAgAAABwCAAAACgAIAAAMABwALAA8AEwAXABsAABM1MxUxNTMVMTUzFTE1MxUHNTMVBzUzFQc1MxWAgICAgICAgICAgAGAgICAgICAgICAgICAgICAgIAAHgAAAAADgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwBTAFcAWwBfAGMAZwBrAG8AcwB3AAATNTMVMTUzFTE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFTM1MxUxNTMVITUzFQU1MxUzNTMVMzUzFTM1MxUFNTMVMzUzFTE1MxUhNTMVBTUzFTM1MxUzNTMVMzUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFTE1MxWAgICAgID9AIACgID8gICAgIABAID8gICAgICAgID8gICAgIABAID8gICAgICAgID8gIACgID9AICAgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAABwAABIADgAUAAAMABwALAA8AEwAXABsAABE1MxUxNTMVMTUzFTE1MxUxNTMVMTUzFTE1MxWAgICAgICABICAgICAgICAgICAgICAgAAAAAAIAIACgAKABIAAAwAHAAsADwATABcAGwAfAAABNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFQEAgID+gIABAID+AIABAID+gICABACAgICAgICAgICAgICAgICAgICAAAAAAA4AgAAAAwADgAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAAAE1MxUHNTMVBTUzFTE1MxUxNTMVMTUzFTE1MxUFNTMVBzUzFQE1MxUxNTMVMTUzFTE1MxUxNTMVAYCAgID+gICAgICA/oCAgID+gICAgICAAwCAgICAgICAgICAgICAgICAgICAgICA/wCAgICAgICAgICAAAoAgAIAAoAEgAADAAcACwAPABMAFwAbAB8AIwAnAAATNTMVMTUzFTE1Mx0BNTMVBTUzFQU1MxUFNTMVMTUzFTE1MxUxNTMVgICAgID/AID/AID/AICAgIAEAICAgICAgICAgICAgICAgICAgICAgICAgAAACgCAAgACgASAAAMABwALAA8AEwAXABsAHwAjACcAABM1MxUxNTMVMTUzHQE1MxUFNTMVMTUzHQE1MxUFNTMVMTUzFTE1MxWAgICAgP6AgICA/gCAgIAEAICAgICAgICAgICAgICAgICAgICAgICAgAAAAAACAYADgAKABIAAAwAHAAABNTMVBTUzFQIAgP8AgAQAgICAgIAAAAAAEQAA/wADgAMAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwAAEzUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFSE1MxUFNTMVMzUzFTE1MxUzNTMVBTUzFQU1MxWAgAGAgP2AgAGAgP2AgAGAgP2AgAGAgP2AgIABAID9gICAgICAgP0AgP8AgAKAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAAGgCA/4ADgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwBTAFcAWwBfAGMAZwAAATUzFTE1MxUxNTMVMTUzFTE1MxUFNTMVMTUzFTE1MxUzNTMVBTUzFTE1MxUxNTMVMzUzFQU1MxUxNTMVMzUzFQU1MxUzNTMVBTUzFTM1MxUFNTMVMzUzFQU1MxUzNTMVBTUzFTM1MxUBAICAgICA/QCAgICAgP2AgICAgID+AICAgID+gICAgP6AgICA/oCAgID+gICAgP6AgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAJAQABAAKAAoAAAwAHAAsADwATABcAGwAfACMAAAE1MxUxNTMVMTUzFQU1MxUxNTMVMTUzFQU1MxUxNTMVMTUzFQEAgICA/oCAgID+gICAgAIAgICAgICAgICAgICAgICAgICAgIAAAAQBgP6AAoAAAAADAAcACwAPAAAFNTMVMTUzFQc1MxUFNTMVAYCAgICA/wCAgICAgICAgICAgIAACACAAgACAASAAAMABwALAA8AEwAXABsAHwAAATUzFQU1MxUxNTMVBzUzFQc1MxUFNTMVMTUzFTE1MxUBAID/AICAgICAgP8AgICABACAgICAgICAgICAgICAgICAgICAgAAAAAoAgAIAAoAEgAADAAcACwAPABMAFwAbAB8AIwAnAAABNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVAQCAgP6AgAEAgP4AgAEAgP4AgAEAgP6AgIAEAICAgICAgICAgICAgICAgICAgICAgICAgAAKAIAAgAMAAwAAAwAHAAsADwATABcAGwAfACMAJwAAEzUzFTM1MxUFNTMVMzUzFQU1MxUzNTMVBTUzFTM1MxUFNTMVMzUzFYCAgID/AICAgP8AgICA/gCAgID+AICAgAKAgICAgICAgICAgICAgICAgICAgICAgICAAAAAFgCAAAADgAUAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwBTAFcAAAE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMzUzFQc1MxUFNTMVITUzFQU1MxUzNTMVMTUzFQU1MxUzNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUCgID9gIABgID9gIABAID+AIABAID+AICAgICA/wCAAQCA/gCAgICA/YCAgICAgID9AIABgIAEgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAABYAgAAAA4AFAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwBLAE8AUwBXAAABNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTM1MxUHNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFTE1MxUxNTMVAoCA/YCAAYCA/YCAAQCA/gCAAQCA/gCAgICAgICA/gCAAYCA/YCAAQCA/YCAAQCA/gCAAQCAgIAEgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAaAAAAAAOABQAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAFMAVwBbAF8AYwBnAAABNTMVBTUzFTE1MxUhNTMVBTUzFTM1MxUFNTMVMTUzFTM1MxUFNTMVMTUzFQU1MxUxNTMVMzUzFQU1MxUhNTMVBTUzFTM1MxUxNTMVBTUzFTM1MxUxNTMVMTUzFTE1MxUFNTMVITUzFQKAgP0AgIABgID+AICAgP4AgICAgP6AgID+AICAgID/AIABAID+AICAgID9gICAgICAgP0AgAGAgASAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAKAIAAAAMABAAAAwAHAAsADwATABcAGwAfACMAJwAAATUzFQM1MxUHNTMVBTUzFQU1MxUHNTMVITUzFQU1MxUxNTMVMTUzFQGAgICAgID/AID/AICAgAGAgP4AgICAA4CAgP8AgICAgICAgICAgICAgICAgICAgICAgIAAEgCAAAADgAUAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAAABNTMdATUzFQE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUBgICA/wCAgP6AgAEAgP4AgAEAgP4AgICAgP2AgAIAgP0AgAIAgP0AgAIAgASAgICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAASAIAAAAOABQAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcAAAE1MxUFNTMVAzUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQIAgP8AgICAgP6AgAEAgP4AgAEAgP4AgICAgP2AgAIAgP0AgAIAgP0AgAIAgASAgICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAABQAgAAAA4AFAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwBLAE8AAAE1MxUxNTMVBTUzFSE1MxUBNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVAYCAgP6AgAEAgP6AgID+gIABAID+AIABAID+AICAgID9gIACAID9AIACAID9AIACAIAEgICAgICAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAAFACAAAADgAUAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwAAATUzFTM1MxUFNTMVMzUzFQE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUBgICAgP4AgICA/wCAgP6AgAEAgP4AgAEAgP4AgICAgP2AgAIAgP0AgAIAgP0AgAIAgASAgICAgICAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAASAIAAAAOABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcAAAE1MxUhNTMVATUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQEAgAEAgP6AgID+gIABAID+AIABAID+AICAgID9gIACAID9AIACAID9AIACAIAEAICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAABYAgAAAA4AFAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwBLAE8AUwBXAAABNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVAYCAgP6AgAEAgP4AgAEAgP6AgID+gIABAID+AIABAID+AICAgID9gIACAID9AIACAID9AIACAIAEgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAXAAAAAAOABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAFMAVwBbAAABNTMVMTUzFTE1MxUxNTMVBTUzFTM1MxUFNTMVMzUzFQU1MxUhNTMVMTUzFQU1MxUxNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUxNTMVMTUzFQGAgICAgP2AgICA/oCAgID+AIABAICA/YCAgICA/YCAAYCA/YCAAYCA/YCAAYCAgIADgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAEQCA/oADgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwAAATUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVBzUzFQc1MxUHNTMdATUzFSE1MxUFNTMVMTUzFTE1MxUFNTMVBzUzFQU1MxUBgICAgP4AgAGAgP0AgICAgICAgIABgID+AICAgP8AgICA/wCAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAAUAIAAAAMABQAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAAABNTMdATUzFQE1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUHNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUHNTMVMTUzFTE1MxUxNTMVMTUzFQEAgID+gICAgICA/YCAgICAgICAgP4AgICAgICAgICABICAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAUAIAAAAMABQAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAAABNTMVBTUzFQE1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUHNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUHNTMVMTUzFTE1MxUxNTMVMTUzFQIAgP8AgP6AgICAgID9gICAgICAgICA/gCAgICAgICAgIAEgICAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAAFQCAAAADAAUAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwBTAAABNTMVBTUzFTM1MxUBNTMVMTUzFTE1MxUxNTMVMTUzFQU1MxUHNTMVBzUzFTE1MxUxNTMVMTUzFQU1MxUHNTMVBzUzFTE1MxUxNTMVMTUzFTE1MxUBgID/AICAgP4AgICAgID9gICAgICAgICA/gCAgICAgICAgIAEgICAgICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAFACAAAADAASAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwAAATUzFTM1MxUBNTMVMTUzFTE1MxUxNTMVMTUzFQU1MxUHNTMVBzUzFTE1MxUxNTMVMTUzFQU1MxUHNTMVBzUzFTE1MxUxNTMVMTUzFTE1MxUBAICAgP4AgICAgID9gICAgICAgICA/gCAgICAgICAgIAEAICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAADQEAAAACgAUAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMAAAE1Mx0BNTMVATUzFTE1MxUxNTMVBTUzFQc1MxUHNTMVBzUzFQc1MxUFNTMVMTUzFTE1MxUBgICA/oCAgID/AICAgICAgICAgP8AgICABICAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgAANAQAAAAKABQAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwAAATUzFQU1MxUBNTMVMTUzFTE1MxUFNTMVBzUzFQc1MxUHNTMVBzUzFQU1MxUxNTMVMTUzFQIAgP8AgP8AgICA/wCAgICAgICAgID/AICAgASAgICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAOAQAAAAKABQAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3AAABNTMVBTUzFTM1MxUBNTMVMTUzFTE1MxUFNTMVBzUzFQc1MxUHNTMVBzUzFQU1MxUxNTMVMTUzFQGAgP8AgICA/oCAgID/AICAgICAgICAgP8AgICABICAgICAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAAA0BAAAAAoAEgAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzAAABNTMVMzUzFQE1MxUxNTMVMTUzFQU1MxUHNTMVBzUzFQc1MxUHNTMVBTUzFTE1MxUxNTMVAQCAgID+gICAgP8AgICAgICAgICA/wCAgIAEAICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAFQAAAAADgAOAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwBTAAATNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxWAgICAgP4AgAGAgP2AgAIAgPyAgICAgAEAgP0AgAIAgP0AgAGAgP2AgICAgAMAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAABkAgAAAA4AFAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwBLAE8AUwBXAFsAXwBjAAABNTMVMzUzFQU1MxUzNTMVATUzFTE1MxUhNTMVBTUzFTM1MxUhNTMVBTUzFTM1MxUhNTMVBTUzFSE1MxUzNTMVBTUzFSE1MxUzNTMVBTUzFSE1MxUxNTMVBTUzFSE1MxUxNTMVAYCAgID+AICAgP4AgIABgID9AICAgAEAgP0AgICAAQCA/QCAAQCAgID9AIABAICAgP0AgAGAgID9AIABgICABICAgICAgICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAABAAgAAAA4AFAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AAABNTMdATUzFQE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVAYCAgP8AgID+gIABAID9gIACAID9AIACAID9AIACAID9gIABAID+gICABICAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAAQAIAAAAOABQAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwAAATUzFQU1MxUDNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFQIAgP8AgICAgP6AgAEAgP2AgAIAgP0AgAIAgP0AgAIAgP2AgAEAgP6AgIAEgICAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAEgCAAAADgAUAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAAABNTMVMTUzFQU1MxUhNTMVATUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUBgICA/oCAAQCA/oCAgP6AgAEAgP2AgAIAgP0AgAIAgP0AgAIAgP2AgAEAgP6AgIAEgICAgICAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAEgCAAAADgAUAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAAABNTMVMzUzFQU1MxUzNTMVATUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUBgICAgP4AgICA/wCAgP6AgAEAgP2AgAIAgP0AgAIAgP0AgAIAgP2AgAEAgP6AgIAEgICAgICAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAEACAAAADgASAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AAAE1MxUhNTMVATUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUBAIABAID+gICA/oCAAQCA/YCAAgCA/QCAAgCA/QCAAgCA/YCAAQCA/oCAgAQAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAkAgACAAwADAAADAAcACwAPABMAFwAbAB8AIwAAEzUzFSE1MxUFNTMVMzUzFQU1MxUFNTMVMzUzFQU1MxUhNTMVgIABgID+AICAgP8AgP8AgICA/gCAAYCAAoCAgICAgICAgICAgICAgICAgICAgICAAAAAFgCAAAADgAQAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwBTAFcAAAE1MxUxNTMVMzUzFQU1MxUhNTMVBTUzFSE1MxUzNTMVBTUzFSE1MxUzNTMVBTUzFTM1MxUhNTMVBTUzFTM1MxUhNTMVBTUzFSE1MxUFNTMVMzUzFTE1MxUBgICAgID9gIABAID9gIABAICAgP0AgAEAgICA/QCAgIABAID9AICAgAEAgP2AgAEAgP2AgICAgAOAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAABIAgAAAA4AFAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwAAATUzHQE1MxUBNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUxNTMVAYCAgP4AgAIAgP0AgAIAgP0AgAIAgP0AgAIAgP0AgAIAgP0AgAIAgP2AgICAgASAgICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAABIAgAAAA4AFAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwAAATUzFQU1MxUBNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUxNTMVAgCA/wCA/oCAAgCA/QCAAgCA/QCAAgCA/QCAAgCA/QCAAgCA/QCAAgCA/YCAgICABICAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAABQAgAAAA4AFAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwBLAE8AAAE1MxUxNTMVBTUzFSE1MxUBNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUxNTMVAYCAgP6AgAEAgP2AgAIAgP0AgAIAgP0AgAIAgP0AgAIAgP0AgAIAgP0AgAIAgP2AgICAgASAgICAgICAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAEgCAAAADgASAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAAABNTMVITUzFQE1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUBAIABAID9gIACAID9AIACAID9AIACAID9AIACAID9AIACAID9AIACAID9gICAgIAEAICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAADQAAAAADgAUAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMAAAE1MxUFNTMVATUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTM1MxUFNTMVBzUzFQc1MxUCAID/AID+AIACgID8gIACgID9AIABgID+AICAgP8AgICAgIAEgICAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAQAIAAAAMABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwAAEzUzFQc1MxUHNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUFNTMVBzUzFYCAgICAgICAgP4AgAGAgP2AgAGAgP2AgICAgP4AgICAA4CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAAGQAA/4ADgASAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwBTAFcAWwBfAGMAAAE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUxNTMVMTUzFQU1MxUBAICAgP4AgAGAgP2AgAGAgP2AgICAgP4AgAGAgP2AgAIAgP0AgAIAgP0AgAIAgP0AgICAgID9AIAEAICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAABIAgAAAAwAEgAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwAAATUzHQE1MxUBNTMVMTUzFTE1Mx0BNTMVBTUzFTE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUxNTMVAYCAgP6AgICAgP4AgICAgP2AgAGAgP2AgAGAgP4AgICAgAQAgICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAEgCAAAADAASAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAAABNTMVBTUzFQE1MxUxNTMVMTUzHQE1MxUFNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUCAID/AID/AICAgID+AICAgID9gIABgID9gIABgID+AICAgIAEAICAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAEwCAAAADAASAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsAAAE1MxUFNTMVMzUzFQE1MxUxNTMVMTUzHQE1MxUFNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUBgID/AICAgP6AgICAgP4AgICAgP2AgAGAgP2AgAGAgP4AgICAgAQAgICAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAUAIAAAAMABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAAABNTMVMzUzFQU1MxUzNTMVATUzFTE1MxUxNTMdATUzFQU1MxUxNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFQGAgICA/gCAgID+gICAgID+AICAgID9gIABgID9gIABgID+AICAgIAEAICAgICAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAABIAgAAAAwAEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwAAATUzFTM1MxUBNTMVMTUzFTE1Mx0BNTMVBTUzFTE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUxNTMVAQCAgID+gICAgID+AICAgID9gIABgID9gIABgID+AICAgIADgICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAFACAAAADAAUAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwAAATUzFQU1MxUzNTMVBTUzFQE1MxUxNTMVMTUzHQE1MxUFNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUBgID/AICAgP8AgP8AgICAgP4AgICAgP2AgAGAgP2AgAGAgP4AgICAgASAgICAgICAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAWAAAAAAOAAwAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAFMAVwAAEzUzFTE1MxUzNTMVMTUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFSE1MxUFNTMVMTUzFTE1MxUxNTMVMTUzFYCAgICAgP6AgAEAgP0AgICAgICA/ICAAQCA/gCAAQCAAQCA/QCAgICAgAKAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAAPAID+gAMAAwAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAAAE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFQc1MxUHNTMVITUzFQU1MxUxNTMVMTUzFQU1MxUHNTMVBTUzFQEAgICA/gCAAYCA/YCAgICAgAGAgP4AgICA/wCAgID/AIACgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAABIAgAAAAwAEgAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwAAATUzHQE1MxUBNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUhNTMVBTUzFTE1MxUxNTMVAQCAgP8AgICA/gCAAYCA/YCAgICAgP2AgICAAYCA/gCAgIAEAICAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAABIAgAAAAwAEgAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwAAATUzFQU1MxUDNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUhNTMVBTUzFTE1MxUxNTMVAYCA/wCAgICAgP4AgAGAgP2AgICAgID9gICAgAGAgP4AgICABACAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAABMAgAAAAwAEgAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwBLAAABNTMVBTUzFTM1MxUBNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUhNTMVBTUzFTE1MxUxNTMVAYCA/wCAgID+gICAgP4AgAGAgP2AgICAgID9gICAgAGAgP4AgICABACAgICAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAABIAgAAAAwAEAAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMARwAAATUzFTM1MxUBNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1MxUxNTMVBTUzFQc1MxUhNTMVBTUzFTE1MxUxNTMVAQCAgID+gICAgP4AgAGAgP2AgICAgID9gICAgAGAgP4AgICAA4CAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAAAAAkBAAAAAgAEgAADAAcACwAPABMAFwAbAB8AIwAAATUzHQE1MxUBNTMVMTUzFQc1MxUHNTMVBzUzFQc1MxUHNTMVAQCAgP8AgICAgICAgICAgICABACAgICAgP8AgICAgICAgICAgICAgICAgICAgAAJAQAAAAIABIAAAwAHAAsADwATABcAGwAfACMAAAE1MxUFNTMVAzUzFTE1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFQGAgP8AgICAgICAgICAgICAgIAEAICAgICA/wCAgICAgICAgICAgICAgICAgICAAAAAAAoBAAAAAoAEgAADAAcACwAPABMAFwAbAB8AIwAnAAABNTMVBTUzFTM1MxUBNTMVMTUzFQc1MxUHNTMVBzUzFQc1MxUHNTMVAYCA/wCAgID+gICAgICAgICAgICAgAQAgICAgICAgP8AgICAgICAgICAgICAgICAgICAgAAJAQAAAAKABIAAAwAHAAsADwATABcAGwAfACMAAAE1MxUzNTMVATUzFTE1MxUHNTMVBzUzFQc1MxUHNTMVBzUzFQEAgICA/oCAgICAgICAgICAgIAEAICAgID+gICAgICAgICAgICAgICAgICAgIAAFACAAAADAASAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAEsATwAAATUzFTE1MxUzNTMVBTUzFQU1MxUzNTMVBzUzFQU1MxUxNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUBAICAgID/AID/AICAgICA/gCAgICA/YCAAYCA/YCAAYCA/YCAAYCA/gCAgIAEAICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAEgCAAAADAASAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAAABNTMVMzUzFQU1MxUzNTMVATUzFTE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUBAICAgP4AgICA/oCAgICA/gCAAYCA/YCAAYCA/YCAAYCA/YCAAYCA/YCAAYCABACAgICAgICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAQAIAAAAMABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwAAATUzHQE1MxUBNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFQEAgID/AICAgP4AgAGAgP2AgAGAgP2AgAGAgP2AgAGAgP4AgICABACAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAABAAgAAAAwAEgAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AAABNTMVBTUzFQE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVAgCA/wCA/wCAgID+AIABgID9gIABgID9gIABgID9gIABgID+AICAgAQAgICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAABEAgAAAAwAEgAADAAcACwAPABMAFwAbAB8AIwAnACsALwAzADcAOwA/AEMAAAE1MxUFNTMVMzUzFQE1MxUxNTMVMTUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVAYCA/wCAgID+gICAgP4AgAGAgP2AgAGAgP2AgAGAgP2AgAGAgP4AgICABACAgICAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAEgCAAAADAASAAAMABwALAA8AEwAXABsAHwAjACcAKwAvADMANwA7AD8AQwBHAAABNTMVMzUzFQU1MxUzNTMVATUzFTE1MxUxNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVMTUzFTE1MxUBgICAgP4AgICA/oCAgID+AIABgID9gIABgID9gIABgID9gIABgID+AICAgAQAgICAgICAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAQAIAAAAMABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwAAATUzFTM1MxUBNTMVMTUzFTE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFQEAgICA/oCAgID+AIABgID9gIABgID9gIABgID9gIABgID+AICAgAOAgICAgP8AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAAAcAgACAAwADAAADAAcACwAPABMAFwAbAAABNTMVATUzFTE1MxUxNTMVMTUzFTE1MxUBNTMVAYCA/oCAgICAgP6AgAKAgID/AICAgICAgICAgID/AICAAAAUAID/gAMAA4AAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAAABNTMVBTUzFTE1MxUxNTMVBTUzFSE1MxUxNTMVBTUzFTM1MxUzNTMVBTUzFTM1MxUzNTMVBTUzFTE1MxUhNTMVBTUzFTE1MxUxNTMVBTUzFQKAgP4AgICA/gCAAQCAgP2AgICAgID9gICAgICA/YCAgAEAgP4AgICA/gCAAwCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAAAAAAQAIAAAAMABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwAAATUzHQE1MxUBNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFQEAgID+gIABgID9gIABgID9gIABgID9gIABgID9gIABgID+AICAgIAEAICAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAQAIAAAAMABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwAAATUzFQU1MxUBNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFQGAgP8AgP8AgAGAgP2AgAGAgP2AgAGAgP2AgAGAgP2AgAGAgP4AgICAgAQAgICAgID/AICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgAARAIAAAAMABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAAABNTMVBTUzFTM1MxUBNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFQGAgP8AgICA/gCAAYCA/YCAAYCA/YCAAYCA/YCAAYCA/YCAAYCA/gCAgICABACAgICAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAQAIAAAAMABAAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwAAATUzFTM1MxUBNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFTE1MxUxNTMVMTUzFQEAgICA/gCAAYCA/YCAAYCA/YCAAYCA/YCAAYCA/YCAAYCA/gCAgICAA4CAgICA/wCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIAAAAAVAID+gAMABIAAAwAHAAsADwATABcAGwAfACMAJwArAC8AMwA3ADsAPwBDAEcASwBPAFMAAAE1MxUFNTMVATUzFSE1MxUFNTMVITUzFQU1MxUhNTMVBTUzFSE1MxUFNTMVITUzFQU1MxUxNTMVMTUzFTE1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MDAxMA51bmljb2RlIzB4MDAxMQ51bmljb2RlIzB4MDAxMg51bmljb2RlIzB4MDAxMw51bmljb2RlIzB4MDAxNA51bmljb2RlIzB4MDAxNQ51bmljb2RlIzB4MDAxNg51bmljb2RlIzB4MDAxNw51bmljb2RlIzB4MDAxOA51bmljb2RlIzB4MDAxOQ51bmljb2RlIzB4MDAxYQ51bmljb2RlIzB4MDAxYg51bmljb2RlIzB4MDAxYw51bmljb2RlIzB4MDAxZA51bmljb2RlIzB4MDAxZQ51bmljb2RlIzB4MDAxZgZkZWxldGUERXVybw51bmljb2RlIzB4MDA4MQ51bmljb2RlIzB4MDA4Mg51bmljb2RlIzB4MDA4Mw51bmljb2RlIzB4MDA4NA51bmljb2RlIzB4MDA4NQ51bmljb2RlIzB4MDA4Ng51bmljb2RlIzB4MDA4Nw51bmljb2RlIzB4MDA4OA51bmljb2RlIzB4MDA4OQ51bmljb2RlIzB4MDA4YQ51bmljb2RlIzB4MDA4Yg51bmljb2RlIzB4MDA4Yw51bmljb2RlIzB4MDA4ZA51bmljb2RlIzB4MDA4ZQ51bmljb2RlIzB4MDA4Zg51bmljb2RlIzB4MDA5MA51bmljb2RlIzB4MDA5MQ51bmljb2RlIzB4MDA5Mg51bmljb2RlIzB4MDA5Mw51bmljb2RlIzB4MDA5NA51bmljb2RlIzB4MDA5NQ51bmljb2RlIzB4MDA5Ng51bmljb2RlIzB4MDA5Nw51bmljb2RlIzB4MDA5OA51bmljb2RlIzB4MDA5OQ51bmljb2RlIzB4MDA5YQ51bmljb2RlIzB4MDA5Yg51bmljb2RlIzB4MDA5Yw51bmljb2RlIzB4MDA5ZA51bmljb2RlIzB4MDA5ZQ51bmljb2RlIzB4MDA5ZgAA")
Drawing.Font.new("Monospace", "rbxasset://fonts/families/RobotoMono.json")
--Drawing.Font.new("Pixel", "AAEAAAAMAIAAAwBAT1MvMmSz/H0AAAFIAAAAYFZETVhoYG/3AAAGmAAABeBjbWFwel+AIwAADHgAAAUwZ2FzcP//AAEAAGP4AAAACGdseWa90hIhAAARqAAARRRoZWFk/hqSzwAAAMwAAAA2aGhlYQegBbsAAAEEAAAAJGhtdHhmdgAAAAABqAAABPBsb2Nh73HeDAAAVrwAAAJ6bWF4cAFBADMAAAEoAAAAIG5hbWX/R4pVAABZOAAABC1wb3N0fPqooAAAXWgAAAaOAAEAAAABAAArGZw2Xw889QAJA+gAAAAAzSamLgAAAADNJqljAAD/OASwAyAAAAAJAAIAAAAAAAAAAQAAAu7/BgAABRQAAABkBLAAAQAAAAAAAAAAAAAAAAAAATwAAQAAATwAMgAEAAAAAAABAAAAAAAAAAAAAAAAAAAAAAADAfMBkAAFAAACvAKKAAD/nAK8AooAAAD6ADIA+gAAAgAAAAAAAAAAAIAAAi8AAAAKAAAAAAAAAABQWVJTAEAAICEiAu7/BgAAAyAAyAAAAAUAAAAAAPoB9AAAACAAAAH0AAAAAAAAAfQAAAH0AAACWAAAAlgAAAJYAAAAyAAAAS0AAAEtAAABkAAAAZAAAAEsAAABkAAAAMgAAAJYAAAB9AAAAZAAAAH0AAAB9AAAAfQAAAH0AAAB9AAAAfQAAAH0AAAB9AAAAMgAAAEsAAABkAAAAZAAAAGQAAAB9AAAAfQAAAH0AAAB9AAAAfQAAAH0AAAB9AAAAfQAAAH0AAAB9AAAAZAAAAH0AAAB9AAAAfQAAAJYAAAB9AAAAfQAAAH0AAAB9AAAAfQAAAH0AAABkAAAAfQAAAGQAAACWAAAAfQAAAGQAAAB9AAAASwAAAJYAAABLAAAAlgAAAH0AAABLAAAAfQAAAH0AAAB9AAAAfQAAAH0AAAB9AAAAfQAAAH0AAABkAAAAfQAAAH0AAAB9AAAAlgAAAH0AAAB9AAAAfQAAAH0AAAB9AAAAfQAAAGQAAAB9AAAAZAAAAJYAAAB9AAAAZAAAAH0AAABkAAAAMgAAAGQAAAB9AAAAlgAAAH0AAABLAAAAfQAAAJYAAACWAAAAZAAAAGQAAACWAAAAyAAAAJYAAABkAAAAlgAAAH0AAACWAAAAZAAAAJYAAABLAAAASwAAAJYAAACWAAAASwAAAGQAAAB9AAAA4QAAAJYAAABkAAAAlgAAAH0AAACWAAAAZAAAAGQAAABkAAAAfQAAAH0AAAB9AAAAMgAAAH0AAAB9AAAAyAAAAH0AAACvAAAAfQAAAEsAAADIAAAAZAAAAGQAAABkAAAAZAAAAGQAAAB9AAAAlgAAAJYAAAAyAAAAfQAAAK8AAAB9AAAArwAAAH0AAAB9AAAAfQAAAGQAAAB9AAAAfQAAAH0AAAB9AAAAlgAAAH0AAACWAAAAfQAAAH0AAAB9AAAAfQAAAH0AAACWAAAAfQAAAH0AAAB9AAAAfQAAAH0AAABkAAAAfQAAAJYAAAB9AAAAlgAAAH0AAACWAAAArwAAAJYAAACvAAAAfQAAAH0AAACWAAAAfQAAAH0AAAB9AAAAfQAAAH0AAACWAAAAfQAAAJYAAAB9AAAAfQAAAH0AAAB9AAAAfQAAAJYAAAB9AAAAfQAAAH0AAAB9AAAAfQAAAGQAAAB9AAAAlgAAAH0AAACWAAAAfQAAAJYAAACvAAAAlgAAAK8AAAB9AAAAfQAAAJYAAAB9AAAAfQAAAH0AAAAyAAAAlgAAAH0AAABkAAAAZAAAAH0AAAB9AAAAfQAAAEsAAABkAAAAZAAAAH0AAAFFAAABRQAAAUUAAAB9AAAAfQAAAH0AAAB9AAAAfQAAAH0AAAB9AAAAlgAAAH0AAAB9AAAAfQAAAH0AAAB9AAAAZAAAAGQAAABkAAAAZAAAAJYAAAB9AAAAfQAAAH0AAAB9AAAAfQAAAH0AAABkAAAAlgAAAH0AAAB9AAAAfQAAAH0AAABkAAAAfQAAAH0AAAB9AAAAfQAAAH0AAAB9AAAAfQAAAH0AAACWAAAAfQAAAH0AAAB9AAAAfQAAAH0AAABkAAAAZAAAAGQAAABkAAAAlgAAAH0AAAB9AAAAfQAAAH0AAAB9AAAAfQAAAGQAAACWAAAAfQAAAH0AAAB9AAAAfQAAAGQAAAB9AAAAZAAAAJYAAACWAAAAfQAAAH0AAABkAAAAfQAAAH0AAAB9AAAAZAAAAH0AAACWAAAAMgAAAGQAAAAAAABAAEBAQEBAAwA+Aj/AAgAB//+AAkACP/+AAoACP/+AAsACf/9AAwACv/9AA0AC//9AA4ADP/9AA8ADP/9ABAADf/8ABEADv/8ABIAD//8ABMAEP/8ABQAEP/8ABUAEf/7ABYAEv/7ABcAE//7ABgAFP/7ABkAFP/7ABoAFf/6ABsAFv/6ABwAF//6AB0AGP/6AB4AGP/6AB8AGf/5ACAAGv/5ACEAG//5ACIAHP/5ACMAHP/5ACQAHf/4ACUAHv/4ACYAH//4ACcAIP/4ACgAIP/4ACkAIf/3ACoAIv/3ACsAI//3ACwAJP/3AC0AJP/3AC4AJf/2AC8AJv/2ADAAJ//2ADEAKP/2ADIAKP/2ADMAKf/1ADQAKv/1ADUAK//1ADYALP/1ADcALP/1ADgALf/0ADkALv/0ADoAL//0ADsAMP/0ADwAMP/0AD0AMf/zAD4AMv/zAD8AM//zAEAANP/zAEEANP/zAEIANf/yAEMANv/yAEQAN//yAEUAOP/yAEYAOP/yAEcAOf/xAEgAOv/xAEkAO//xAEoAPP/xAEsAPP/xAEwAPf/wAE0APv/wAE4AP//wAE8AQP/wAFAAQP/wAFEAQf/vAFIAQv/vAFMAQ//vAFQARP/vAFUARP/vAFYARf/uAFcARv/uAFgAR//uAFkASP/uAFoASP/uAFsASf/tAFwASv/tAF0AS//tAF4ATP/tAF8ATP/tAGAATf/sAGEATv/sAGIAT//sAGMAUP/sAGQAUP/sAGUAUf/rAGYAUv/rAGcAU//rAGgAVP/rAGkAVP/rAGoAVf/qAGsAVv/qAGwAV//qAG0AWP/qAG4AWP/qAG8AWf/pAHAAWv/pAHEAW//pAHIAXP/pAHMAXP/pAHQAXf/oAHUAXv/oAHYAX//oAHcAYP/oAHgAYP/oAHkAYf/nAHoAYv/nAHsAY//nAHwAZP/nAH0AZP/nAH4AZf/mAH8AZv/mAIAAZ//mAIEAaP/mAIIAaP/mAIMAaf/lAIQAav/lAIUAa//lAIYAbP/lAIcAbP/lAIgAbf/kAIkAbv/kAIoAb//kAIsAcP/kAIwAcP/kAI0Acf/jAI4Acv/jAI8Ac//jAJAAdP/jAJEAdP/jAJIAdf/iAJMAdv/iAJQAd//iAJUAeP/iAJYAeP/iAJcAef/hAJgAev/hAJkAe//hAJoAfP/hAJsAfP/hAJwAff/gAJ0Afv/gAJ4Af//gAJ8AgP/gAKAAgP/gAKEAgf/fAKIAgv/fAKMAg//fAKQAhP/fAKUAhP/fAKYAhf/eAKcAhv/eAKgAh//eAKkAiP/eAKoAiP/eAKsAif/dAKwAiv/dAK0Ai//d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ATkBOgE7ATwBPQE+AT8BQAFBAUIBQwFEAUUBRgFHAUgBSQFKAUsBTAFNAU4BTwFQAVEBUgFTAVQBVQFWAVcBWAFZAVoBWwFcAV0BXgFfAWABYQFiAWMBZAFlAWYAowCEAIUAlgCOAJ0A8gDzAI0A3gDxAJ4A9QD0APYAogCtAMkAxwCuAGIAYwCQAGQAywBlAMgAygDPAMwAzQDOAOkAZgDTANAA0QCvAGcA8ACRANYA1ADVAGgA6wDtAIkAagBpAGsAbQBsAG4AoABvAHEAcAByAHMAdQB0AHYAdwDqAHgAegB5AHsAfQB8ALgAoQB/AH4AgACBAOwA7gC6ALAAsQDkAOUAuwDmAOcApgDYANkABgAEAAUFLm51bGwJYWZpaTEwMDUxCWFmaWkxMDA1MglhZmlpMTAxMDAERXVybwlhZmlpMTAwNTgJYWZpaTEwMDU5CWFmaWkxMDA2MQlhZmlpMTAwNjAJYWZpaTEwMTQ1CWFmaWkxMDA5OQlhZmlpMTAxMDYJYWZpaTEwMTA3CWFmaWkxMDEwOQlhZmlpMTAxMDgJYWZpaTEwMTkzCWFmaWkxMDA2MglhZmlpMTAxMTAJYWZpaTEwMDU3CWFmaWkxMDA1MAlhZmlpMTAwMjMJYWZpaTEwMDUzB3VuaTAwQUQJYWZpaTEwMDU2CWFmaWkxMDA1NQlhZmlpMTAxMDMJYWZpaTEwMDk4DnBlcmlvZGNlbnRlcmVkCWFmaWkxMDA3MQlhZmlpNjEzNTIJYWZpaTEwMTAxCWFmaWkxMDEwNQlhZmlpMTAwNTQJYWZpaTEwMTAyCWFmaWkxMDEwNAlhZmlpMTAwMTcJYWZpaTEwMDE4CWFmaWkxMDAxOQlhZmlpMTAwMjAJYWZpaTEwMDIxCWFmaWkxMDAyMglhZmlpMTAwMjQJYWZpaTEwMDI1CWFmaWkxMDAyNglhZmlpMTAwMjcJYWZpaTEwMDI4CWFmaWkxMDAyOQlhZmlpMTAwMzAJYWZpaTEwMDMxCWFmaWkxMDAzMglhZmlpMTAwMzMJYWZpaTEwMDM0CWFmaWkxMDAzNQlhZmlpMTAwMzYJYWZpaTEwMDM3CWFmaWkxMDAzOAlhZmlpMTAwMzkJYWZpaTEwMDQwCWFmaWkxMDA0MQlhZmlpMTAwNDIJYWZpaTEwMDQzCWFmaWkxMDA0NAlhZmlpMTAwNDUJYWZpaTEwMDQ2CWFmaWkxMDA0NwlhZmlpMTAwNDgJYWZpaTEwMDQ5CWFmaWkxMDA2NQlhZmlpMTAwNjYJYWZpaTEwMDY3CWFmaWkxMDA2OAlhZmlpMTAwNjkJYWZpaTEwMDcwCWFmaWkxMDA3MglhZmlpMTAwNzMJYWZpaTEwMDc0CWFmaWkxMDA3NQlhZmlpMTAwNzYJYWZpaTEwMDc3CWFmaWkxMDA3OAlhZmlpMTAwNzkJYWZpaTEwMDgwCWFmaWkxMDA4MQlhZmlpMTAwODIJYWZpaTEwMDgzCWFmaWkxMDA4NAlhZmlpMTAwODUJYWZpaTEwMDg2CWFmaWkxMDA4NwlhZmlpMTAwODgJYWZpaTEwMDg5CWFmaWkxMDA5MAlhZmlpMTAwOTEJYWZpaTEwMDkyCWFmaWkxMDA5MwlhZmlpMTAwOTQJYWZpaTEwMDk1CWFmaWkxMDA5NglhZmlpMTAwOTcNYWZpaTEwMDQ1LjAwMQ1hZmlpMTAwNDcuMDAxAAAAAAAB//8AAA==")

env.Drawing = Drawing
env.cleardrawcache = Drawing.ClearCache
