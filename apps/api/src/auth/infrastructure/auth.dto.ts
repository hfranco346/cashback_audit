import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

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
