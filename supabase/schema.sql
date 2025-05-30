-- Create tables for the agent application

-- Create a table for user profiles
CREATE TABLE IF NOT EXISTS profiles (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
  email TEXT NOT NULL,
  display_name TEXT,
  avatar_url TEXT,
  email_scan_permission BOOLEAN DEFAULT FALSE
);

-- Create a table for tasks
CREATE TABLE IF NOT EXISTS tasks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
  title TEXT NOT NULL,
  completed BOOLEAN DEFAULT FALSE,
  due_date TIMESTAMP WITH TIME ZONE,
  user_id UUID REFERENCES auth.users NOT NULL
);

-- Create a table for financial goals
CREATE TABLE IF NOT EXISTS financial_goals (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
  title TEXT NOT NULL,
  target DECIMAL NOT NULL,
  current DECIMAL NOT NULL,
  target_date TIMESTAMP WITH TIME ZONE,
  color TEXT DEFAULT '#174E4F',
  user_id UUID REFERENCES auth.users NOT NULL
);

-- Create a table for expenses (without payment_id reference initially)
CREATE TABLE IF NOT EXISTS expenses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
  category TEXT NOT NULL,
  amount DECIMAL NOT NULL,
  date TIMESTAMP WITH TIME ZONE NOT NULL,
  user_id UUID REFERENCES auth.users NOT NULL
);

-- Create a table for payments
CREATE TABLE IF NOT EXISTS payments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
  title TEXT NOT NULL,
  amount DECIMAL NOT NULL,
  due_date TIMESTAMP WITH TIME ZONE NOT NULL,
  recurring BOOLEAN DEFAULT FALSE,
  category TEXT NOT NULL,
  paid BOOLEAN DEFAULT FALSE,
  user_id UUID REFERENCES auth.users NOT NULL
);

-- Set up Row Level Security (RLS) policies

-- Enable RLS on all tables (except detected_bills which will be enabled later)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE financial_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Create policies for profiles
CREATE POLICY IF NOT EXISTS "Users can view their own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY IF NOT EXISTS "Users can update their own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- Create policies for tasks
CREATE POLICY IF NOT EXISTS "Users can view their own tasks"
  ON tasks FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY IF NOT EXISTS "Users can create their own tasks"
  ON tasks FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY IF NOT EXISTS "Users can update their own tasks"
  ON tasks FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY IF NOT EXISTS "Users can delete their own tasks"
  ON tasks FOR DELETE
  USING (auth.uid() = user_id);

-- Create policies for financial goals
CREATE POLICY IF NOT EXISTS "Users can view their own financial goals"
  ON financial_goals FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY IF NOT EXISTS "Users can create their own financial goals"
  ON financial_goals FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY IF NOT EXISTS "Users can update their own financial goals"
  ON financial_goals FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY IF NOT EXISTS "Users can delete their own financial goals"
  ON financial_goals FOR DELETE
  USING (auth.uid() = user_id);

-- Create policies for expenses
CREATE POLICY IF NOT EXISTS "Users can view their own expenses"
  ON expenses FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY IF NOT EXISTS "Users can create their own expenses"
  ON expenses FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY IF NOT EXISTS "Users can update their own expenses"
  ON expenses FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY IF NOT EXISTS "Users can delete their own expenses"
  ON expenses FOR DELETE
  USING (auth.uid() = user_id);

-- Create a table for detected bills from emails
CREATE TABLE IF NOT EXISTS detected_bills (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
  title TEXT NOT NULL,
  amount DECIMAL NOT NULL,
  due_date TIMESTAMP WITH TIME ZONE NOT NULL,
  category TEXT NOT NULL,
  confidence DECIMAL NOT NULL,
  source TEXT NOT NULL,
  approved BOOLEAN DEFAULT FALSE,
  user_id UUID REFERENCES auth.users NOT NULL
);

-- Create policies for payments
CREATE POLICY IF NOT EXISTS "Users can view their own payments"
  ON payments FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY IF NOT EXISTS "Users can create their own payments"
  ON payments FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY IF NOT EXISTS "Users can update their own payments"
  ON payments FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY IF NOT EXISTS "Users can delete their own payments"
  ON payments FOR DELETE
  USING (auth.uid() = user_id);

-- Create policies for detected bills
CREATE POLICY IF NOT EXISTS "Users can view their own detected bills"
  ON detected_bills FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY IF NOT EXISTS "Users can create their own detected bills"
  ON detected_bills FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY IF NOT EXISTS "Users can update their own detected bills"
  ON detected_bills FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY IF NOT EXISTS "Users can delete their own detected bills"
  ON detected_bills FOR DELETE
  USING (auth.uid() = user_id);

-- Now enable RLS on detected_bills
ALTER TABLE detected_bills ENABLE ROW LEVEL SECURITY;

-- Add payment_id reference to expenses table now that payments table exists
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS payment_id UUID REFERENCES payments(id) NULL;

-- Create a function to handle new user signups
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email)
  VALUES (new.id, new.email);
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a trigger to call the function when a new user signs up
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
