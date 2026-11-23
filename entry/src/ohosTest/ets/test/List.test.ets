import abilityTest from './Ability.test';
import cryptoServiceTest from './CryptoService.test';
import storageServiceTest from './StorageService.test';
import base32UtilsTest from './Base32Utils.test';
import totpServiceTest from './TotpService.test';
import otpParserTest from './OtpParser.test';

export default function testsuite() {
  abilityTest();
  cryptoServiceTest();
  storageServiceTest();
  base32UtilsTest();
  totpServiceTest();
  otpParserTest();
}