ALTER TABLE public.products ADD COLUMN IF NOT EXISTS country_of_manufacture text;
COMMENT ON COLUMN public.products.country_of_manufacture IS 'Actual tyre manufacturing country (Made in), not brand origin';
