class O
	module HashMethodFix
	def _merge! obj
		_child.merge! O.get(obj)
		self
	end

	def _merge obj
		data = _child.merge(O.get(obj))
		O[data]
	end
	end
end
