module.exports = {
  parser: '@typescript-eslint/parser',
  plugins: ['@typescript-eslint', 'import'],
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended'
  ],
  rules: {
    '@typescript-eslint/no-explicit-any': 'off',
    '@typescript-eslint/no-unused-vars': 'off',
    'import/no-restricted-paths': [
      'error',
      {
        zones: [
          {
            target: './src/modules/auth/**/*',
            from: './src/modules/!(auth)/**/src/**/*',
            message: 'Cross-module private imports are forbidden. Only import from module/index.ts'
          },
          {
            target: './src/modules/matching/**/*',
            from: './src/modules/!(matching)/**/src/**/*',
            message: 'Cross-module private imports are forbidden. Only import from module/index.ts'
          },
          {
            target: './src/modules/trip/**/*',
            from: './src/modules/!(trip)/**/src/**/*',
            message: 'Cross-module private imports are forbidden. Only import from module/index.ts'
          },
          {
            target: './src/modules/payment/**/*',
            from: './src/modules/!(payment)/**/src/**/*',
            message: 'Cross-module private imports are forbidden. Only import from module/index.ts'
          },
          {
            target: './src/modules/pricing/**/*',
            from: './src/modules/!(pricing)/**/src/**/*',
            message: 'Cross-module private imports are forbidden. Only import from module/index.ts'
          },
          {
            target: './src/modules/kyc/**/*',
            from: './src/modules/!(kyc)/**/src/**/*',
            message: 'Cross-module private imports are forbidden. Only import from module/index.ts'
          },
          {
            target: './src/modules/notification/**/*',
            from: './src/modules/!(notification)/**/src/**/*',
            message: 'Cross-module private imports are forbidden. Only import from module/index.ts'
          }
        ]
      }
    ]
  }
};
