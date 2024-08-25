#!/bin/bash

# 색깔 변수 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Sonic 데일리퀘스트 미션 스크립트를 시작합니다...${NC}"

# 작업 디렉토리 설정
workDir2="/root/sonic-daily"

# 기존 작업 디렉토리가 존재하면 삭제
if [ -d "$workDir2" ]; then
    echo -e "${YELLOW}작업 디렉토리 '${workDir2}'가 이미 존재하므로 삭제합니다.${NC}"
    rm -rf "$workDir2"
fi

# 작업 디렉토리 새로 생성
echo -e "${YELLOW}새로운 작업 디렉토리 '${workDir2}'를 생성합니다.${NC}"
mkdir -p "$workDir2"
cd "$workDir2"

# 파일 다운로드 및 덮어쓰기
echo -e "${YELLOW}필요한 파일들을 다운로드합니다...${NC}"

# 존재하는 파일을 삭제하고 다운로드
rm -f package.json
curl -o package.json https://raw.githubusercontent.com/KangJKJK/sonic-checkin/main/package.json

rm -f package-lock.json
curl -o package-lock.json https://raw.githubusercontent.com/KangJKJK/sonic-checkin/main/package-lock.json

# npm 설치 여부 확인
echo -e "${YELLOW}필요한 파일들을 설치합니다...${NC}"
if ! command -v npm &> /dev/null; then
    echo -e "${RED}npm이 설치되지 않았습니다. npm을 설치합니다...${NC}"
    sudo apt-get update
    sudo apt-get install -y npm
else
    echo -e "${GREEN}npm이 이미 설치되어 있습니다.${NC}"
fi

# Node.js 모듈 설치
echo -e "${YELLOW}필요한 Node.js 모듈을 설치합니다...${NC}"
npm install
npm install @solana/web3.js chalk bs58

# 개인키 입력받기
read -p "Solana의 개인키를 쉼표로 구분하여 입력하세요: " privkeys

# 개인키를 파일에 저장
echo "$privkeys" > "$workDir2/sonicprivate.txt"

# 파일 생성 확인
if [ -f "$workDir2/sonicprivate.txt" ]; then
    echo -e "${GREEN}개인키 파일이 성공적으로 생성되었습니다.${NC}"
else
    echo -e "${RED}개인키 파일 생성에 실패했습니다.${NC}"
fi

# Node.js 스크립트 작성 (sonic-daily.mjs)
echo -e "${YELLOW}Node.js 스크립트를 작성하고 있습니다...${NC}"
cat << 'EOF' > sonic-daily.mjs
// sonic-daily.mjs
import path from 'path';
import fs from 'fs';
import { Connection, Keypair, Transaction } from '@solana/web3.js';
import bs58 from 'bs58';
import nacl from 'tweetnacl';
import fetch from 'node-fetch';

// 작업 디렉토리 설정
const workDir2 = '/root/sonic-daily';
if (!fs.existsSync(workDir2)) {
    // 작업 디렉토리가 존재하지 않으면 새로 생성합니다.
    fs.mkdirSync(workDir2, { recursive: true });
}
process.chdir(workDir2); // 현재 작업 디렉토리를 설정한 디렉토리로 변경합니다.

// 개인키 목록 읽기
const listAccounts = fs.readFileSync(path.join(workDir2, 'sonicprivate.txt'), 'utf-8')
    .split(",") // 개인키 목록을 쉼표로 분리하여 배열로 변환합니다.
    .map(a => a.trim()); // 각 항목의 앞뒤 공백을 제거합니다.

if (listAccounts.length === 0) {
    // 개인키가 하나도 없으면 오류를 발생시킵니다.
    throw new Error('sonicprivate.txt에 개인키를 하나 이상 입력해주세요.');
}

// Solana 네트워크에 연결 설정
const connection = new Connection('https://devnet.sonic.game/', 'confirmed');

// 개인키로부터 Keypair 객체를 생성하는 함수
function getKeypairFromPrivateKey(privateKey) {
    const decoded = bs58.decode(privateKey); // 개인키를 base58로 디코딩합니다.
    return Keypair.fromSecretKey(decoded); // 디코딩된 키를 사용하여 Keypair 객체를 생성합니다.
}

// 거래를 보내는 함수
async function sendTransaction(transaction, keyPair) {
    try {
        transaction.partialSign(keyPair); // 거래에 서명을 추가합니다.
        const rawTransaction = transaction.serialize(); // 거래를 직렬화하여 원시 거래 데이터를 생성합니다.
        const signature = await connection.sendRawTransaction(rawTransaction); // 원시 거래 데이터를 네트워크에 전송하고 서명을 받습니다.
        await connection.confirmTransaction(signature); // 거래가 확정될 때까지 기다립니다.
        return signature; // 거래의 서명을 반환합니다.
    } catch (error) {
        // 오류 발생 시 오류를 반환합니다.
        return error;
    }
}

// 지연을 위한 함수 (초 단위)
const delay = (seconds) => new Promise((resolve) => setTimeout(resolve, seconds * 1000));

// 일일 마일스톤 보상을 클레임하는 함수
const dailyMilestone = async (auth, stage) => {
    let success = false;
    while (!success) {
        try {
            // 현재 일일 상태를 요청합니다.
            await fetch('https://odyssey-api.sonic.game/user/transactions/state/daily', {
                method: 'GET',
                headers: {
                    ...defaultHeaders,
                    'authorization': `${auth}`
                }
            });

            // 마일스톤 보상을 클레임합니다.
            const data = await fetch('https://odyssey-api.sonic.game/user/transactions/rewards/claim', {
                method: 'POST',
                headers: {
                    ...defaultHeaders,
                    'authorization': `${auth}`
                },
                body: JSON.stringify({
                    'stage': stage
                })
            }).then(res => res.json());

            if (data.message == 'interact rewards already claimed') {
                // 이미 클레임한 경우 메시지를 반환합니다.
                success = true;
                return `마일스톤 ${stage} 이미 클레임했습니다!`;
            }

            if (data.data) {
                // 마일스톤 보상이 성공적으로 클레임되면 메시지를 반환합니다.
                success = true;
                return `성공적으로 마일스톤 ${stage} 보상을 클레임했습니다.`;
            }
        } catch (e) {
            // 오류 발생 시 재시도합니다.
        }
    }
};

// 미스터리 박스를 열고 보상을 확인하는 함수
const openBox = async (keyPair, auth) => {
    let success = false;
    while (!success) {
        try {
            // 미스터리 박스 거래를 요청합니다.
            const data = await fetch('https://odyssey-api.sonic.game/user/rewards/mystery-box/build-tx', {
                headers: {
                    ...defaultHeaders,
                    'authorization': auth
                }
            }).then(res => res.json());

            if (data.data) {
                const transactionBuffer = Buffer.from(data.data.hash, "base64"); // 거래 해시를 base64로 디코딩합니다.
                const transaction = Transaction.from(transactionBuffer); // 거래 객체를 생성합니다.
                transaction.partialSign(keyPair); // 거래에 서명을 추가합니다.
                const signature = await sendTransaction(transaction, keyPair); // 거래를 네트워크에 전송하고 서명을 받습니다.
                const open = await fetch('https://odyssey-api.sonic.game/user/rewards/mystery-box/open', {
                    method: 'POST',
                    headers: {
                        ...defaultHeaders,
                        'authorization': auth
                    },
                    body: JSON.stringify({
                        'hash': signature
                    })
                }).then(res => res.json());

                // 미스터리 박스를 성공적으로 열면 보상 메시지를 반환합니다.
                success = true;
                return `성공적으로 미스터리 박스를 열었습니다, ${open.data.reward}!`;
            }
        } catch (e) {
            // 오류 발생 시 재시도합니다.
        }
    }
};

// 개인키 처리
(async () => {
    const totalKeys = listAccounts.length; // 총 개인키 수를 계산합니다.
    for (let i = 0; i < totalKeys; i++) {
        const privateKey = listAccounts[i]; // 현재 개인키를 가져옵니다.
        const keypair = getKeypairFromPrivateKey(privateKey); // 개인키로 Keypair 객체를 생성합니다.
        const publicKey = keypair.publicKey.toBase58(); // 공개키를 base58로 변환합니다.
        const initialBalance = await connection.getBalance(keypair.publicKey); // 초기 잔액을 조회합니다.
        console.log(`지갑주소: ${publicKey}`); // 지갑 주소를 출력합니다.
        const initialBalance = await connection.getBalance(keypair.publicKey); // 초기 잔액을 조회합니다.
        const progress = ((i + 1) / totalKeys * 100).toFixed(2); // 처리 진행 상태를 계산합니다.
        console.log(`처리 진행 상태: ${progress}% (${i + 1}/${totalKeys})`); // 처리 상태를 출력합니다.

        await new Promise(resolve => setTimeout(resolve, 1000)); // 1초 대기 후 다음 개인키를 처리합니다.
    }
})();
EOF

echo -e "${YELLOW}Node.js 스크립트를 작성했습니다.${NC}"

# Node.js 스크립트 실행
echo -e "${GREEN}Node.js 스크립트를 실행합니다...${NC}"
node --no-deprecation sonic-daily.mjs

echo -e "${GREEN}모든 작업이 완료되었습니다. 컨트롤+A+D로 스크린을 종료해주세요.${NC}"
echo -e "${GREEN}스크립트 작성자: https://t.me/kjkresearch${NC}"
