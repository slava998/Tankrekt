// by Splittingred

shared class HoverMessageShiprekt
{
	int quantity;
	string name;
	u32 ticker;
	f32 ypos;
	f32 xpos;
	u32 ttl;
	u32 fade_ratio;
	SColor color;

	HoverMessageShiprekt() {} // required for handles to work

	HoverMessageShiprekt(string&in _name, const int&in _quantity, const SColor&in _color = color_white, const u32&in _ttl = 75, const u32&in _fade_ratio = 2, const bool&in singularise = true)
	{
		if (_quantity >= 0 && _quantity < 2 && singularise) 
		{
			_name = singularize(_name);
		}

		name = _name;
		quantity = _quantity;
		ticker = 0;
		ypos = 0.0f;
		xpos = 0.0f;
		ttl = _ttl;
		fade_ratio = _fade_ratio;
		color = _color;
	}

	// draw the text
	void draw(CBlob@ blob)
	{
		const string m = message();
		const Vec2f pos = getPos(blob, m);
		const SColor color = getColor();
		GUI::DrawText(m, pos, color);
	}

	// get message into a nice, friendly format
	const string message()
	{
		const string d = "" + quantity + " " + name;
		return d;
	}

	// see if this message is expired, or should be removed from GUI
	const bool isExpired()
	{
		ticker++;
		return ticker > ttl;
	}

	// get the active color of the message. decrease proportionally by the fadeout ratio
	private SColor getColor()
	{
		const u32 alpha = Maths::Max(0, 255-(ticker * fade_ratio));
		const SColor color2(alpha, color.getRed(), color.getGreen(), color.getBlue());
		return color2;
	}

	// get the position of the message. Store it to the object if no pos is already set. This allows us to do the
	// hovering above where it was picked effect. Finally, slowly make it rise by decreasing by a multiple of the ticker
	private Vec2f getPos(CBlob@ blob, const string&in m)
	{
		if (ypos == 0.0f)
		{
			Vec2f pos2d = blob.getScreenPos();
			const int top = pos2d.y - 2.5f * blob.getHeight() - 20.0f;
			const int margin = 4;
			Vec2f dim;
			GUI::GetTextDimensions(m , dim);
			dim.x = Maths::Min(dim.x, 200.0f);
			dim.x += margin;
			dim.y += margin;
			dim.y /= 3.8f;
			ypos = pos2d.x-dim.x/2;
			xpos = top - 2*dim.y;
		}

		xpos -= ticker / 40;
		Vec2f pos(ypos, xpos);
		return pos;
	}

	// Singularize, or de-pluralize, a string
	private const string singularize(string&in str)
	{
		const u32 len = str.size();
		const string lastChar = str.substr(len-1);

		if (lastChar == "s")
			str = str.substr(0, len-1);

		return str;
	}
};

// by Splittingred

shared class HoverMessageShiprekt2
{
	int quantity;
	string prefix;
	string name;
	u32 ticker;
	f32 ypos;
	f32 xpos;
	u32 ttl;
	u32 fade_ratio;
	SColor color;

	HoverMessageShiprekt2() {} // required for handles to work

	HoverMessageShiprekt2(string _name, const int&in _quantity, const SColor&in _color = color_white, const u32&in _ttl = 75, const u32&in _fade_ratio = 2, const bool&in singularise = true, const string&in _prefix = "") 
	{
		if (_quantity >= 0 &&_quantity < 2 && singularise) 
		{
			_name = singularize(_name);
		}

		prefix = _prefix;
		name = _name;
		quantity = _quantity;
		ticker = 0;
		ypos = 0.0;
		xpos = 0.0;
		ttl = _ttl;
		fade_ratio = _fade_ratio;
		color = _color;
	}

	// draw the text
	void draw(const Vec2f&in pos) 
	{
		const string m = message();
		const SColor color = getColor();
		GUI::DrawText(m, pos, color);
	}
	
	void drawDeltaBooty(CBlob@ blob) 
	{
		const string m = message();
		const Vec2f pos = Vec2f(158, 11);
		const SColor color = getColor();
		GUI::DrawText(m, pos, color);
	}

	// get message into a nice, friendly format
	const string message()
	{
		const string d = "" + prefix + quantity + " " + name;
		return d;
	}

	// see if this message is expired, or should be removed from GUI
	const bool isExpired()
	{
		ticker++;
		return ticker > ttl;
	}

	// get the active color of the message. decrease proportionally by the fadeout ratio
	private SColor getColor()
	{
		const u32 alpha = Maths::Max(0, 255-(ticker * fade_ratio));
		const SColor color2(alpha, color.getRed(), color.getGreen(), color.getBlue());
		return color2;
	}

	// get the position of the message. Store it to the object if no pos is already set. This allows us to do the
	// hovering above where it was picked effect. Finally, slowly make it rise by decreasing by a multiple of the ticker
	private Vec2f getPos(CBlob@ blob, const string&in m)
	{
		if (ypos == 0.0)
		{
			Vec2f pos2d = blob.getScreenPos();
			const int top = pos2d.y - 2.5f * blob.getHeight() - 20.0f;
			const int margin = 4;
			Vec2f dim;
			GUI::GetTextDimensions(m , dim);
			dim.x = Maths::Min(dim.x, 200.0f);
			dim.x += margin;
			dim.y += margin;
			dim.y /= 3.8f;
			ypos = pos2d.x-dim.x/2;
			xpos = top - 2*dim.y;
		}

		xpos =- ticker / 40;
		const Vec2f pos(ypos, xpos);
		return pos;
	}

	// Singularize, or de-pluralize, a string
	private const string singularize(string&in str)
	{
		const u32 len = str.size();
		const string lastChar = str.substr(len-1);

		if (lastChar == "s")
			str = str.substr(0, len-1);

		return str;
	}
};
