import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import {
  IsEmail,
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
} from 'class-validator';

const trimmed = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;
const normalizedEmail = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim().toLowerCase() : value;

export class GoogleSignInDto {
  @ApiProperty({
    description: 'Google ID token from the native Google sign-in',
  })
  @IsString()
  @IsNotEmpty()
  @MaxLength(8192)
  idToken!: string;
}

export class AppleSignInDto {
  @ApiProperty({
    description: 'Apple identityToken (JWT) from Sign in with Apple',
  })
  @IsString()
  @IsNotEmpty()
  @MaxLength(8192)
  identityToken!: string;

  @ApiPropertyOptional({
    description:
      'Full name composed by the app from givenName + familyName. Apple only provides it on the first sign-in; send it whenever available.',
  })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  fullName?: string;
}

export class RefreshDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  @MaxLength(8192)
  refreshToken!: string;
}

export class EmailStartDto {
  @ApiProperty({
    example: 'ana@example.com',
    description: 'Trimmed and lowercased by the server',
  })
  @Transform(normalizedEmail)
  @IsEmail()
  @MaxLength(254)
  email!: string;

  @ApiPropertyOptional({
    enum: ['es', 'en'],
    description: 'Email language (default es)',
  })
  @IsOptional()
  @IsIn(['es', 'en'])
  locale?: 'es' | 'en';
}

export class EmailVerifyDto {
  @ApiProperty({ example: 'ana@example.com' })
  @Transform(normalizedEmail)
  @IsEmail()
  @MaxLength(254)
  email!: string;

  @ApiProperty({
    example: '123456',
    description: '6-digit code from the email',
  })
  @Transform(trimmed)
  @IsString()
  @Matches(/^\d{6}$/, { message: 'code must be 6 digits' })
  code!: string;
}
