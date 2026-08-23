# transactions に (user_id, category_id) / (user_id, payment_method_id) の複合FKを張り、
# 他ユーザーの category/payment_method 混入を DB 層でも拒否する（多層防御・#113）。
# 単一列FKでは「category が存在するか」しか見ず越境を許すため、複合FKへ置き換える。
#
# 列指定 ON DELETE SET NULL は PostgreSQL 15+ 機能（dev 16 / CI 17）。
#
# 単一 DDL トランザクション（Rails 既定）で原子的に実行する。FK 追加は既存行の検証スキャンを
# 伴い書き込みを短時間ロックするが、対象は小規模のため許容範囲。将来 transactions が肥大化して
# ロックが問題になる場合は NOT VALID で追加 → VALIDATE CONSTRAINT（弱いロック）へ分割する。
class AddCompositeTenantForeignKeysToTransactions < ActiveRecord::Migration[8.1]
  def up
    # 複合FKのターゲットには UNIQUE 制約が必要（unique インデックスだけでは不可）。
    # 既存の unique インデックスを USING INDEX で制約へ昇格する（再スキャンなし）。
    execute <<~SQL
      ALTER TABLE categories
        ADD CONSTRAINT uq_categories_user_id_id
        UNIQUE USING INDEX index_categories_on_user_id_and_id
    SQL
    execute <<~SQL
      ALTER TABLE payment_methods
        ADD CONSTRAINT uq_payment_methods_user_id_id
        UNIQUE USING INDEX index_payment_methods_on_user_id_and_id
    SQL

    # 単一列FKを削除し複合FKへ置き換える。
    remove_foreign_key :transactions, :categories
    remove_foreign_key :transactions, :payment_methods

    # (user_id, category_id) → categories(user_id, id)。
    # カテゴリ削除時は category_id だけ NULL 化（user_id は NOT NULL のため列指定 SET NULL）。
    # category_id が NULL の行は MATCH SIMPLE で制約対象外（未分類を許容）。
    execute <<~SQL
      ALTER TABLE transactions
        ADD CONSTRAINT fk_transactions_user_category
        FOREIGN KEY (user_id, category_id)
        REFERENCES categories (user_id, id)
        ON DELETE SET NULL (category_id)
    SQL

    # (user_id, payment_method_id) → payment_methods(user_id, id)。
    # payment_method_id は NOT NULL のため常に検査。ON DELETE は元の単一列FKと同じ NO ACTION
    # （既定）を維持する。物理削除はアプリ層で先にアーカイブへ倒す。RESTRICT にしないのは、
    # user 削除の CASCADE（#110）で payment_methods と transactions が同時に消える経路を、
    # NO ACTION の文末遅延評価で阻害しないため（RESTRICT は即時評価で失敗し得る）。
    execute <<~SQL
      ALTER TABLE transactions
        ADD CONSTRAINT fk_transactions_user_payment_method
        FOREIGN KEY (user_id, payment_method_id)
        REFERENCES payment_methods (user_id, id)
    SQL
  end

  def down
    execute "ALTER TABLE transactions DROP CONSTRAINT fk_transactions_user_payment_method"
    execute "ALTER TABLE transactions DROP CONSTRAINT fk_transactions_user_category"

    # 単一列FKを復元する。
    add_foreign_key :transactions, :categories, on_delete: :nullify
    add_foreign_key :transactions, :payment_methods

    # UNIQUE 制約を落とすと裏のインデックスも消えるため、元の unique インデックスを作り直す。
    execute "ALTER TABLE payment_methods DROP CONSTRAINT uq_payment_methods_user_id_id"
    execute "ALTER TABLE categories DROP CONSTRAINT uq_categories_user_id_id"
    add_index :categories, [ :user_id, :id ], unique: true, name: "index_categories_on_user_id_and_id"
    add_index :payment_methods, [ :user_id, :id ], unique: true, name: "index_payment_methods_on_user_id_and_id"
  end
end
