%
% A structure that handles a list of recently used strings.
% The values are added to the list using different strategies concerning
% duplicate entries in the list.
%
% The code was taken from mini.sl and packed in a structure. This way the code
% can be reused for different purposes.
% 
% History:
%   2006-03-13: Marko Mahnic
%     - initial version
%   2006-09-21: Marko Mahnic
%     - added set_values
%   2007-02-11: Marko Mahnic
%     - added is_empty

provide("hist-cls");

% The structure/class for history list manipulation.
% Members whose names start with an underscore should be considered private.
!if (is_defined ("HISTORY_Type"))
{
   typedef struct
   {
      % Array of strings
      _Values,
      % The oldest line
      _first_idx,
      % The future line, should be considered empty on startup
      _last_idx,         
      % The current line, used for navigation in the history (prev, next)
      _next_idx,
      % Currently unused; will be used if _Values will grow dynamically
      max_length,        

      % if -2, never store duplicates, move Most-Recently-Used to first position
      % If -1, store only if not equal to last entered value
      % If 0, never store duplicates
      strategy,

      % ------- methods
      init,              % (max_values); Clears the history
      _do_store_value,   % (value); Stores the value
      store_value,       % (value); Stores the value using strategy
      value_exists,      % (value); returns 1 if falue exists in history
      set_last_value,    % (value); Sets the last value, but only when eohp
      get_current_value, % : value;
      get_values,        % ( &nValues ): array of values;
      set_values,        % ( aValues ); Sets the array of values
      bohp,              % : integer; Nonzero if at beginning of history
      eohp,              % : integer; Nonzero if at end of history
      is_empty,          % : integer; Nonzero if empty
      next,
      prev
   } HISTORY_Type;
};

private define mm_hist_init(self, maxvalues)
{
   self.max_length = maxvalues;
   self._Values = String_Type[maxvalues];
   self._Values[[:]] = "";
   self._first_idx = 0;
   self._last_idx = 0;
   self._next_idx = 0;
}

% True if at the last (newest) entry in the history. 
private define mm_hist_eohp(self)
{
   return self._next_idx == self._last_idx;
}

% True if at the first (oldest) entry in the history. 
private define mm_hist_bohp(self)
{
   return self._next_idx == self._first_idx;
}

% Move forward in history, from oldest to newest
private define mm_hist_next(self)
{
   if (self.eohp()) 
     return; % error ("End of list!");

   variable MX = length(self._Values);
   self._next_idx = (self._next_idx + 1) mod MX;
}

% Move backwards in history, from newest to oldest.
private define mm_hist_prev(self)
{
   if (self.bohp())
     return; % error ("Top of list!");

   variable MX = length(self._Values);
   variable prev = (self._next_idx + MX - 1) mod MX;
   if (self._last_idx == self._next_idx and prev != self._first_idx)
   {
      if (self._Values[prev] == self._Values[self._next_idx])
         prev = (prev + MX - 1) mod MX;
   }
      
   self._next_idx = prev;
}

% Store the nonempty value s to the end of history array.
% _last_idx is increased and if it becomes same as _first_idx
% then _first_idx is increased.
% _next_idx becomes _last_idx and eohp() becomes true.
private define mm_hist_do_store_value (self, s)
{
   if ((s == NULL) or (s == Null_String))
     return;

   variable MX = length(self._Values);
   self._Values[self._last_idx] = s;
   self._last_idx = (self._last_idx + 1) mod MX;
   if (self._last_idx == self._first_idx)
      self._first_idx = (self._first_idx + 1) mod MX;
   self._next_idx = self._last_idx;
   self._Values[self._last_idx] = "";
}


%% This should usually happen before first call to self.prev
%% Works only if at end of history (next_idx = last_idx)
private define mm_hist_set_last_value(self, value)
{
   !if (self.eohp()) return;
   self._Values[self._last_idx] = value;
}

% Get the value that is currently selected in the history list
private define mm_hist_get_current_value(self)
{
   return self._Values[self._next_idx];
}

% Returns nonzero when the history is empty.
private define mm_hist_is_empty(self)
{
   return self._last_idx == self._first_idx;
}

% Returns true when value exists in the history array, between _first_idx and
% _last_idx - 1.
private define mm_hist_value_exists(self, value)
{
   if (self.is_empty()) return 0;
   
   variable MX = length(self._Values);
   variable i = (self._last_idx + MX - 1) mod MX;
   do
   {
      if (value == self._Values[i]) return 1;
      i = (i + MX - 1) mod MX;
   } while (i != self._first_idx);
   
   return 0;
}

% Depending on the strategy used, add value to the history array and/or
% move the other values accordingly.
private define mm_hist_store_value(self, value)
{
   variable MX = length(self._Values);
   self._next_idx = self._last_idx;

   switch (self.strategy)
   {
      case 0:		       %  never
        if (length (where (value == self._Values)))
           value = NULL;
   }
   {
    case -1:		       %  sometimes
      variable i = (self._next_idx + MX - 1) mod MX;
      if (self._Values[i] == value)
         value = NULL;
   }
   {
    case -2:		       %  never, use MRU
      variable il, delta, la = self._last_idx;
      if (la < self._first_idx) la = la + MX;
      delta = 0;
      il = self._first_idx;
      while (il < la)
      {
         if (self._Values[il mod MX] == value) delta++;
         if (delta)
         {
            if ((il + delta) > la) break;
            else
               self._Values[il mod MX] = self._Values[(il + delta) mod MX];
         }
         il++;
      }
      if (delta)
      {
         self._last_idx = (self._last_idx + MX - delta) mod MX;
         self._next_idx = self._last_idx;
      }
   }
   self._do_store_value (value);
}

% Return an array of valid stored values.
% If num_p is not NULL, set its value to the maximum length of history entries.
private define mm_hist_get_values (self, num_p)
{
   variable MX = length(self._Values);
   variable n = self._last_idx - self._first_idx;

   if (num_p != NULL)
     @num_p = MX;

   if (n < 0)
     n += (MX+1);
   
   variable values = String_Type [n];
   
   n = self._last_idx - self._first_idx;
   if (n < 0)
     {
	n = MX - self._first_idx;
	values[[0:n-1]] = self._Values[[self._first_idx:]];
	values[[n:]] = self._Values[[0:self._last_idx]];
	return values;
     }
   
   return self._Values[[0:n-1]];
}

% Set the history array to aValues. 
% aValues[0] represents the oldest value in the history array.
private define mm_hist_set_values (self, aValues)
{
   variable n = length(aValues);
   variable MX = length(self._Values);
  
   if (n >= MX) n = MX-1;
   self._Values[[0:n-1]] = aValues;
   self._first_idx = 0;
   self._last_idx = n;
   self._next_idx = self._last_idx;
}

% Create a history list structure/object that will hold at most
% maxvalues items.
public define New_History_Type(maxvalues)
{
   variable hist = @HISTORY_Type;

   hist.init = &mm_hist_init;
   hist.next = &mm_hist_next;
   hist.prev = &mm_hist_prev;
   hist._do_store_value = &mm_hist_do_store_value;
   hist.value_exists = &mm_hist_value_exists;
   hist.store_value = &mm_hist_store_value;
   hist.set_last_value = &mm_hist_set_last_value;
   hist.get_current_value = &mm_hist_get_current_value;
   hist.get_values = &mm_hist_get_values;
   hist.set_values = &mm_hist_set_values;
   hist.eohp = &mm_hist_eohp;
   hist.bohp = &mm_hist_bohp;
   hist.is_empty = &mm_hist_is_empty;
   
   hist.init(maxvalues);
   hist.strategy = -2;
   
   return hist;
}

